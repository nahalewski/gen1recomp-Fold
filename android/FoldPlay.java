package org.love2d.android;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import androidx.annotation.Keep;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.google.android.gms.nearby.Nearby;
import com.google.android.gms.nearby.connection.AdvertisingOptions;
import com.google.android.gms.nearby.connection.ConnectionInfo;
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback;
import com.google.android.gms.nearby.connection.ConnectionResolution;
import com.google.android.gms.nearby.connection.ConnectionsClient;
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo;
import com.google.android.gms.nearby.connection.DiscoveryOptions;
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback;
import com.google.android.gms.nearby.connection.Payload;
import com.google.android.gms.nearby.connection.PayloadCallback;
import com.google.android.gms.nearby.connection.PayloadTransferUpdate;
import com.google.android.gms.nearby.connection.Strategy;
import com.google.android.gms.tasks.OnFailureListener;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.libsdl.app.SDLActivity;

/**
 * Download Play (fold3ds/dlplay.lua): one phone hosts a game's package
 * (its saves and mods, zipped by FoldBridge), the other finds it and
 * receives it.  Google's Nearby Connections carries it: it finds the other
 * phone over Bluetooth and moves the transfer to Wi-Fi Direct / Wi-Fi
 * whenever that is faster, so the quickest link is always the one used.
 *
 * Commands (FoldBridge "dp.<cmd>"): host "<zip>|<name>|<game>",
 * join "<name>", connect "<endpoint id>", stop, status, receivedTo "<dir>".
 * status returns lines of key=value: state, peer, peers (id:name;...),
 * done, total, error, file, game, medium.
 */
final class FoldPlay {
    private static final String TAG = "FoldPlay";
    private static final String SERVICE = "com.nahalewski.aeondx.downloadplay";
    private static final int PERMISSION_REQUEST = 7302;

    private static ConnectionsClient client;
    private static volatile String state = "idle";   // idle asking hosting searching connecting sending receiving done error
    private static String error = "";
    private static String myName = "3DS";
    private static String zipPath, gameName = "";
    private static String peerId, peerName = "";
    private static final Map<String, String> peers = new LinkedHashMap<String, String>();
    private static long done, total;
    private static long startedAt;
    private static long outgoingId = -1;
    private static Payload incoming;
    private static String receivedFile = "";
    private static String receiveDir = "";
    private static String pendingHost;              // waiting on permissions
    private static long askedAt;

    private FoldPlay() {}

    private static Activity activity() {
        Context c = SDLActivity.getContext();
        return (c instanceof Activity) ? (Activity) c : null;
    }

    private static String[] permissions() {
        List<String> p = new ArrayList<String>();
        if (Build.VERSION.SDK_INT >= 31) {
            p.add(Manifest.permission.BLUETOOTH_SCAN);
            p.add(Manifest.permission.BLUETOOTH_ADVERTISE);
            p.add(Manifest.permission.BLUETOOTH_CONNECT);
        }
        if (Build.VERSION.SDK_INT >= 33) p.add("android.permission.NEARBY_WIFI_DEVICES");
        // Nearby Connections still checks location on every Android version
        // (error 8034 MISSING_PERMISSION_ACCESS_COARSE_LOCATION without it)
        p.add(Manifest.permission.ACCESS_COARSE_LOCATION);
        p.add(Manifest.permission.ACCESS_FINE_LOCATION);
        return p.toArray(new String[0]);
    }

    private static boolean permitted(Activity a) {
        for (String p : permissions()) {
            if (ContextCompat.checkSelfPermission(a, p) != PackageManager.PERMISSION_GRANTED) return false;
        }
        return true;
    }

    // asks for the radios' permissions; true when they are already there
    private static boolean ask(final Activity a) {
        if (permitted(a)) return true;
        state = "asking";
        askedAt = System.currentTimeMillis();
        a.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ActivityCompat.requestPermissions(a, permissions(), PERMISSION_REQUEST);
            }
        });
        return false;
    }

    private static ConnectionsClient client(Activity a) {
        if (client == null) client = Nearby.getConnectionsClient(a);
        return client;
    }

    private static void fail(String why) {
        Log.d(TAG, "error: " + why);
        error = why == null ? "" : why;
        state = "error";
    }

    private static final OnFailureListener onFail = new OnFailureListener() {
        @Override
        public void onFailure(@NonNull Exception e) {
            fail(e.getMessage());
        }
    };

    static String call(String cmd, String arg) {
        Activity a = activity();
        if (a == null) return "error:no activity";
        if (cmd.equals("host")) {
            stop();
            String[] p = arg.split("\\|", 3);
            zipPath = p[0];
            myName = p.length > 1 && p[1].length() > 0 ? p[1] : "3DS";
            gameName = p.length > 2 ? p[2] : "";
            pendingHost = "host";
            if (!ask(a)) return state;
            return startHosting(a);
        }
        if (cmd.equals("join")) {
            stop();
            myName = arg.length() > 0 ? arg : "3DS";
            pendingHost = "join";
            if (!ask(a)) return state;
            return startSearching(a);
        }
        if (cmd.equals("connect")) {
            if (!peers.containsKey(arg)) return "error:gone";
            peerId = arg;
            peerName = peers.get(arg);
            state = "connecting";
            client(a).stopDiscovery();
            client(a).requestConnection(myName, arg, lifecycle).addOnFailureListener(onFail);
            return state;
        }
        if (cmd.equals("receivedTo")) {
            receiveDir = arg;
            return "ok";
        }
        if (cmd.equals("stop")) {
            stop();
            return "idle";
        }
        if (cmd.equals("status")) return status(a);
        return "error:unknown dp." + cmd;
    }

    private static String startHosting(Activity a) {
        File f = new File(zipPath);
        if (!f.isFile()) { fail("nothing to send"); return state; }
        total = f.length();
        done = 0;
        state = "hosting";
        AdvertisingOptions o = new AdvertisingOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build();
        client(a).startAdvertising(myName + "|" + gameName, SERVICE, lifecycle, o).addOnFailureListener(onFail);
        return state;
    }

    private static String startSearching(Activity a) {
        peers.clear();
        state = "searching";
        DiscoveryOptions o = new DiscoveryOptions.Builder().setStrategy(Strategy.P2P_POINT_TO_POINT).build();
        client(a).startDiscovery(SERVICE, discovery, o).addOnFailureListener(onFail);
        return state;
    }

    private static String status(Activity a) {
        // the permission prompt answered: carry on
        if (state.equals("asking")) {
            if (permitted(a)) {
                if ("host".equals(pendingHost)) startHosting(a);
                else startSearching(a);
            } else if (System.currentTimeMillis() - askedAt > 1500 && a.hasWindowFocus()) {
                // the prompt has gone and something was refused
                fail("MISSING_PERMISSION");
            }
        }
        StringBuilder b = new StringBuilder();
        b.append("state=").append(state).append('\n');
        b.append("peer=").append(peerName).append('\n');
        b.append("game=").append(gameName).append('\n');
        b.append("done=").append(done).append('\n');
        b.append("total=").append(total).append('\n');
        long ms = Math.max(1, System.currentTimeMillis() - startedAt);
        b.append("speed=").append(startedAt > 0 ? done * 1000 / ms : 0).append('\n');
        b.append("file=").append(receivedFile).append('\n');
        b.append("error=").append(error.replace('\n', ' ')).append('\n');
        b.append("peers=");
        for (Map.Entry<String, String> e : peers.entrySet()) {
            b.append(e.getKey()).append(':').append(e.getValue().replace(';', ',')).append(';');
        }
        b.append('\n');
        return b.toString();
    }

    private static void stop() {
        if (client != null) {
            try {
                client.stopAdvertising();
                client.stopDiscovery();
                client.stopAllEndpoints();
            } catch (Exception e) {
                // stopping anyway
            }
        }
        peers.clear();
        peerId = null;
        peerName = "";
        incoming = null;
        outgoingId = -1;
        done = total = 0;
        startedAt = 0;
        error = "";
        receivedFile = "";
        state = "idle";
    }

    // ------------------------------------------------------------ Nearby

    private static final EndpointDiscoveryCallback discovery = new EndpointDiscoveryCallback() {
        @Override
        public void onEndpointFound(@NonNull String id, @NonNull DiscoveredEndpointInfo info) {
            peers.put(id, info.getEndpointName());
        }

        @Override
        public void onEndpointLost(@NonNull String id) {
            peers.remove(id);
        }
    };

    private static final ConnectionLifecycleCallback lifecycle = new ConnectionLifecycleCallback() {
        @Override
        public void onConnectionInitiated(@NonNull String id, @NonNull ConnectionInfo info) {
            // Download Play: the host hands its package to whoever asks
            peerId = id;
            if (peerName.length() == 0) peerName = info.getEndpointName();
            state = "connecting";
            client.acceptConnection(id, payloads).addOnFailureListener(onFail);
        }

        @Override
        public void onConnectionResult(@NonNull String id, @NonNull ConnectionResolution result) {
            if (!result.getStatus().isSuccess()) {
                fail("the other phone didn't connect");
                return;
            }
            if (zipPath != null && "host".equals(pendingHost)) {
                client.stopAdvertising();
                send(id);
            } else {
                state = "receiving";
            }
        }

        @Override
        public void onDisconnected(@NonNull String id) {
            if (!state.equals("done") && !state.equals("idle")) fail("the connection was lost");
        }
    };

    private static void send(String id) {
        try {
            File f = new File(zipPath);
            String header = "G1RDP1|" + gameName + "|" + f.getName() + "|" + f.length();
            client.sendPayload(id, Payload.fromBytes(header.getBytes(StandardCharsets.UTF_8)));
            Payload p = Payload.fromFile(f);
            outgoingId = p.getId();
            total = f.length();
            done = 0;
            startedAt = System.currentTimeMillis();
            state = "sending";
            client.sendPayload(id, p).addOnFailureListener(onFail);
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }

    private static final PayloadCallback payloads = new PayloadCallback() {
        @Override
        public void onPayloadReceived(@NonNull String id, @NonNull Payload payload) {
            if (payload.getType() == Payload.Type.BYTES) {
                String header = new String(payload.asBytes(), StandardCharsets.UTF_8);
                String[] p = header.split("\\|");
                if (p.length >= 4 && p[0].equals("G1RDP1")) {
                    gameName = p[1];
                    try { total = Long.parseLong(p[3]); } catch (NumberFormatException e) { total = 0; }
                }
            } else if (payload.getType() == Payload.Type.FILE) {
                incoming = payload;
                startedAt = System.currentTimeMillis();
                state = "receiving";
            }
        }

        @Override
        public void onPayloadTransferUpdate(@NonNull String id, @NonNull PayloadTransferUpdate u) {
            boolean mine = u.getPayloadId() == outgoingId
                || (incoming != null && u.getPayloadId() == incoming.getId());
            if (!mine) return;
            done = u.getBytesTransferred();
            if (u.getTotalBytes() > 0) total = u.getTotalBytes();
            int s = u.getStatus();
            if (s == PayloadTransferUpdate.Status.SUCCESS) {
                if (incoming != null && u.getPayloadId() == incoming.getId()) keep(incoming);
                else state = "done";
                client.disconnectFromEndpoint(id);
            } else if (s == PayloadTransferUpdate.Status.FAILURE || s == PayloadTransferUpdate.Status.CANCELED) {
                fail("the transfer stopped");
            }
        }
    };

    // the received package into the save folder
    private static void keep(Payload p) {
        try {
            Payload.File pf = p.asFile();
            if (pf == null) { fail("no file"); return; }
            File dir = new File(receiveDir.length() > 0 ? receiveDir : activity().getFilesDir().getPath());
            dir.mkdirs();
            File out = new File(dir, "received.zip");
            ParcelFileDescriptor pfd = pf.asParcelFileDescriptor();
            InputStream in = new FileInputStream(pfd.getFileDescriptor());
            OutputStream os = new FileOutputStream(out);
            try {
                FoldBridge.copy(in, os);
            } finally {
                os.close();
                in.close();
                pfd.close();
            }
            receivedFile = out.getAbsolutePath();
            state = "done";
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }
}
