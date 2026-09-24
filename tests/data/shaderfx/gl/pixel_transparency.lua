return {["parameter_overrides"]={{["name"]="PT_PALETTE",["value"]=1,},{["name"]="PT_POLARIZER",["value"]=0,},{["name"]="PT_HIGHLIGHTS",["value"]=0,},},["pass_count"]=1,["passes"]={{["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
\
const vec2 _356[5] = vec2[](vec2(0.0), vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(0.0, -1.0), vec2(0.0, 1.0));\
const vec2 _414[9] = vec2[](vec2(0.0), vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(0.0, -1.0), vec2(0.0, 1.0), vec2(-1.0), vec2(1.0, -1.0), vec2(-1.0, 1.0), vec2(1.0));\
\
struct LIBRA_UBO_FRAGMENT\
{\
    mat4 MVP;\
    vec3 Gyroscope;\
    vec3 Accelerometer;\
    vec3 AccelerometerRest;\
    float PT_HIDE_CONTENT;\
    float PT_PALETTE;\
    float PT_PALETTE_INTENSITY;\
    float PT_BACKING_BRIGHTNESS;\
    float PT_POLARIZER;\
    float PT_POLARIZER_TINT;\
    float PT_SATURATION;\
    float PT_HIGHLIGHTS;\
    float PT_WHITE_BOOST;\
    float PT_WHITE_TRANSPARENCY;\
    float PT_BRIGHTNESS_GRID;\
};\
\
uniform LIBRA_UBO_FRAGMENT LIBRA_UBO_FRAGMENT_INSTANCE;\
\
struct LIBRA_PUSH_FRAGMENT\
{\
    vec4 SourceSize;\
    vec4 OutputSize;\
    float PT_ACCEL_ENABLE;\
    float PT_ACCEL_SENSITIVITY;\
    float PT_SHADOW_MOTION;\
    float PT_SHADOW_MAX_OFFSET;\
    float PT_SHADOW_MOTION_X;\
    float PT_SHADOW_MOTION_Y;\
    float PT_SHADOW_OFFSET_X;\
    float PT_SHADOW_OFFSET_Y;\
    float PT_ENABLE;\
    float PT_BRIGHTNESS_MODE;\
    float PT_SHADOW_ENABLE;\
    float PT_SHADOW_BLUR;\
    float PT_SHADOW_OPACITY;\
    float PT_THRESHOLD;\
    float PT_SHADOW_FAST_BLUR;\
    float PT_PIXEL_MODE;\
    float PT_BASE_ALPHA;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
uniform sampler2D LIBRA_TEXTURE_Original;\
\
varying vec2 LIBRA_VARYING_0;\
varying vec2 LIBRA_VARYING_3;\
varying float LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_1;\
\
float getPerceptualBrightness(vec3 color)\
{\
    return ((0.2125999927520751953125 * color.x) + (0.715200006961822509765625 * color.y)) + (0.072200000286102294921875 * color.z);\
}\
\
bool isWhitePixel(vec3 color, float threshold)\
{\
    vec3 param = color;\
    float brightness = getPerceptualBrightness(param);\
    float min_channel = min(min(color.x, color.y), color.z);\
    bool _111 = brightness > threshold;\
    bool _119;\
    if (_111)\
    {\
        _119 = min_channel > (threshold * 0.89999997615814208984375);\
    }\
    else\
    {\
        _119 = _111;\
    }\
    return _119;\
}\
\
float hash(vec2 p)\
{\
    vec3 p3 = fract(p.xyx * 0.103100001811981201171875);\
    p3 += vec3(dot(p3, p3.yzx + vec3(33.3300018310546875)));\
    return fract((p3.x + p3.y) * p3.z);\
}\
\
float paperNoise(vec2 uv, float scale)\
{\
    vec2 p = (uv * scale) * 512.0;\
    float n = 0.0;\
    float amplitude = 0.5;\
    float frequency = 1.0;\
    for (int i = 0; i < 3; i++)\
    {\
        vec2 param = p * frequency;\
        n += (hash(param) * amplitude);\
        amplitude *= 0.5;\
        frequency *= 2.0;\
    }\
    return n;\
}\
\
vec3 generateProceduralBackground(vec2 uv)\
{\
    vec3 baseColor = vec3(LIBRA_UBO_FRAGMENT_INSTANCE.PT_BACKING_BRIGHTNESS);\
    vec2 param = uv;\
    float param_1 = 0.25;\
    float grain = paperNoise(param, param_1);\
    float grainOffset = (grain - 0.4375) * 0.064999997615814208984375;\
    return baseColor + vec3(grainOffset);\
}\
\
float getGameBoyRGBSum(vec3 color)\
{\
    return ((color.x + color.y) + color.z) / 3.0;\
}\
\
float getBrightness(vec3 color)\
{\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_BRIGHTNESS_MODE < 0.5)\
    {\
        vec3 param = color;\
        return getGameBoyRGBSum(param);\
    }\
    else\
    {\
        vec3 param_1 = color;\
        return getPerceptualBrightness(param_1);\
    }\
}\
\
void main()\
{\
    vec4 lcd_color = texture2D(LIBRA_TEXTURE_Source, LIBRA_VARYING_0);\
    vec4 output_color = lcd_color;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_ENABLE < 0.5)\
    {\
        gl_FragData[0] = output_color;\
        return;\
    }\
    vec3 original_pixel = texture2D(LIBRA_TEXTURE_Original, LIBRA_VARYING_0).xyz;\
    if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_HIDE_CONTENT > 0.5)\
    {\
        lcd_color = vec4(1.0);\
        original_pixel = vec3(1.0);\
        output_color = lcd_color;\
    }\
    if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_HIGHLIGHTS < (-0.001000000047497451305389404296875))\
    {\
        vec3 param = lcd_color.xyz;\
        float luma = getPerceptualBrightness(param);\
        vec4 _274 = lcd_color;\
        vec3 _276 = _274.xyz * max(1.0 + (LIBRA_UBO_FRAGMENT_INSTANCE.PT_HIGHLIGHTS * luma), 0.0);\
        lcd_color.x = _276.x;\
        lcd_color.y = _276.y;\
        lcd_color.z = _276.z;\
    }\
    vec3 param_1 = original_pixel;\
    float param_2 = LIBRA_PUSH_FRAGMENT_INSTANCE.PT_THRESHOLD;\
    bool current_is_white = isWhitePixel(param_1, param_2);\
    vec2 param_3 = LIBRA_VARYING_0;\
    vec4 background = vec4(generateProceduralBackground(param_3), 1.0);\
    bool _303 = LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_ENABLE > 0.5;\
    bool _310;\
    if (_303)\
    {\
        _310 = LIBRA_UBO_FRAGMENT_INSTANCE.PT_HIDE_CONTENT < 1.5;\
    }\
    else\
    {\
        _310 = _303;\
    }\
    if (_310)\
    {\
        vec2 shadow_offset = ((-LIBRA_VARYING_3) * LIBRA_VARYING_2) * LIBRA_VARYING_1;\
        float shadow_strength = 0.0;\
        if (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_BLUR > 0.100000001490116119384765625)\
        {\
            vec2 blur_dist = LIBRA_VARYING_1 * (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_BLUR * LIBRA_VARYING_2);\
            float blurred_shadow = 0.0;\
            if (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_FAST_BLUR < 0.5)\
            {\
                for (int i = 0; i < 5; i++)\
                {\
                    vec2 sample_pos = (LIBRA_VARYING_0 + shadow_offset) + (_356[i] * blur_dist);\
                    vec3 blur_sample = texture2D(LIBRA_TEXTURE_Original, sample_pos).xyz;\
                    float w = (i == 0) ? 4.0 : 2.0;\
                    vec3 param_4 = blur_sample;\
                    float blur_brightness = getBrightness(param_4);\
                    blurred_shadow += ((1.0 - blur_brightness) * w);\
                }\
                shadow_strength = (blurred_shadow / 12.0) * LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_OPACITY;\
            }\
            else\
            {\
                float _442;\
                for (int i_1 = 0; i_1 < 9; i_1++)\
                {\
                    vec2 sample_pos_1 = (LIBRA_VARYING_0 + shadow_offset) + (_414[i_1] * blur_dist);\
                    vec3 blur_sample_1 = texture2D(LIBRA_TEXTURE_Original, sample_pos_1).xyz;\
                    if (i_1 == 0)\
                    {\
                        _442 = 4.0;\
                    }\
                    else\
                    {\
                        _442 = (i_1 < 5) ? 2.0 : 1.0;\
                    }\
                    float w_1 = _442;\
                    vec3 param_5 = blur_sample_1;\
                    float blur_brightness_1 = getBrightness(param_5);\
                    blurred_shadow += ((1.0 - blur_brightness_1) * w_1);\
                }\
                shadow_strength = (blurred_shadow / 16.0) * LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_OPACITY;\
            }\
        }\
        else\
        {\
            vec3 center_source = texture2D(LIBRA_TEXTURE_Original, LIBRA_VARYING_0 + shadow_offset).xyz;\
            vec3 param_6 = center_source;\
            float shadow_source_brightness = getBrightness(param_6);\
            shadow_strength = (1.0 - shadow_source_brightness) * LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_OPACITY;\
        }\
        float deadzone = (1.0 - LIBRA_PUSH_FRAGMENT_INSTANCE.PT_THRESHOLD) * LIBRA_PUSH_FRAGMENT_INSTANCE.PT_SHADOW_OPACITY;\
        if (deadzone > 0.001000000047497451305389404296875)\
        {\
            shadow_strength = smoothstep(0.0, deadzone, shadow_strength) * shadow_strength;\
        }\
        vec4 _502 = background;\
        vec4 _504 = background;\
        vec3 _510 = mix(_502.xyz, _504.xyz * 0.20000000298023223876953125, vec3(shadow_strength));\
        background.x = _510.x;\
        background.y = _510.y;\
        background.z = _510.z;\
    }\
    if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_PALETTE > 0.5)\
    {\
        vec3 bg_palette_color;\
        if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_PALETTE < 1.5)\
        {\
            bg_palette_color = vec3(0.65100002288818359375, 0.675000011920928955078125, 0.51800000667572021484375);\
        }\
        else\
        {\
            if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_PALETTE < 2.5)\
            {\
                bg_palette_color = vec3(0.7200000286102294921875, 0.730000019073486328125, 0.660000026226043701171875);\
            }\
            else\
            {\
                if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_PALETTE < 3.5)\
                {\
                    bg_palette_color = vec3(0.765999972820281982421875, 0.730000019073486328125, 0.763000011444091796875);\
                }\
                else\
                {\
                    bg_palette_color = vec3(0.7599999904632568359375);\
                }\
            }\
        }\
        float max_ch = max(bg_palette_color.x, max(bg_palette_color.y, bg_palette_color.z));\
        bg_palette_color *= (0.675000011920928955078125 / max_ch);\
        vec3 tinted_background = clamp(vec3(bg_palette_color.x + mix(-1.0, 1.0, background.x), bg_palette_color.y + mix(-1.0, 1.0, background.y), bg_palette_color.z + mix(-1.0, 1.0, background.z)), vec3(0.0), vec3(1.0));\
        vec4 _592 = background;\
        vec3 _599 = mix(_592.xyz, tinted_background, vec3(LIBRA_UBO_FRAGMENT_INSTANCE.PT_PALETTE_INTENSITY));\
        background.x = _599.x;\
        background.y = _599.y;\
        background.z = _599.z;\
    }\
    vec3 brightness_source = original_pixel;\
    if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_BRIGHTNESS_GRID > 0.001000000047497451305389404296875)\
    {\
        brightness_source = lcd_color.xyz;\
        if (current_is_white)\
        {\
            float white_blend = smoothstep(0.0500000007450580596923828125, 1.0, LIBRA_UBO_FRAGMENT_INSTANCE.PT_BRIGHTNESS_GRID);\
            brightness_source = mix(original_pixel, lcd_color.xyz, vec3(white_blend));\
        }\
    }\
    bool _632 = LIBRA_PUSH_FRAGMENT_INSTANCE.PT_PIXEL_MODE > 0.5;\
    bool _638;\
    if (_632)\
    {\
        _638 = LIBRA_PUSH_FRAGMENT_INSTANCE.PT_PIXEL_MODE < 1.5;\
    }\
    else\
    {\
        _638 = _632;\
    }\
    if (_638)\
    {\
        vec3 param_7 = brightness_source;\
        float pixel_intensity = getBrightness(param_7);\
        float transparency = (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_BASE_ALPHA * pixel_intensity) * 2.66499996185302734375;\
        bool _659;\
        if (current_is_white)\
        {\
            _659 = LIBRA_UBO_FRAGMENT_INSTANCE.PT_WHITE_BOOST > 0.5;\
        }\
        else\
        {\
            _659 = current_is_white;\
        }\
        if (_659)\
        {\
            transparency = max(transparency, LIBRA_UBO_FRAGMENT_INSTANCE.PT_WHITE_TRANSPARENCY);\
        }\
        transparency = clamp(transparency, 0.0, 1.0);\
        vec3 _674 = mix(lcd_color.xyz, background.xyz, vec3(transparency));\
        output_color.x = _674.x;\
        output_color.y = _674.y;\
        output_color.z = _674.z;\
    }\
    else\
    {\
        bool should_apply = (LIBRA_PUSH_FRAGMENT_INSTANCE.PT_PIXEL_MODE < 0.5) ? current_is_white : true;\
        if (should_apply)\
        {\
            vec3 param_8 = brightness_source;\
            float pixel_intensity_1 = getBrightness(param_8);\
            float pixel_alpha = (pixel_intensity_1 / 3.0) + LIBRA_PUSH_FRAGMENT_INSTANCE.PT_BASE_ALPHA;\
            bool _708;\
            if (current_is_white)\
            {\
                _708 = LIBRA_UBO_FRAGMENT_INSTANCE.PT_WHITE_BOOST > 0.5;\
            }\
            else\
            {\
                _708 = current_is_white;\
            }\
            if (_708)\
            {\
                pixel_alpha = max(pixel_alpha, LIBRA_UBO_FRAGMENT_INSTANCE.PT_WHITE_TRANSPARENCY);\
            }\
            pixel_alpha = clamp(pixel_alpha, 0.0, 1.0);\
            vec3 _723 = mix(lcd_color.xyz, background.xyz, vec3(pixel_alpha));\
            output_color.x = _723.x;\
            output_color.y = _723.y;\
            output_color.z = _723.z;\
        }\
    }\
    bool _733 = LIBRA_UBO_FRAGMENT_INSTANCE.PT_POLARIZER > 0.5;\
    bool _739;\
    if (_733)\
    {\
        _739 = LIBRA_UBO_FRAGMENT_INSTANCE.PT_POLARIZER_TINT > 0.001000000047497451305389404296875;\
    }\
    else\
    {\
        _739 = _733;\
    }\
    if (_739)\
    {\
        vec3 polarizer = mix(vec3(1.0), vec3(0.939999997615814208984375, 1.0, 0.8650000095367431640625), vec3(LIBRA_UBO_FRAGMENT_INSTANCE.PT_POLARIZER_TINT));\
        vec4 _751 = output_color;\
        vec3 _753 = _751.xyz * polarizer;\
        output_color.x = _753.x;\
        output_color.y = _753.y;\
        output_color.z = _753.z;\
    }\
    if (LIBRA_UBO_FRAGMENT_INSTANCE.PT_HIGHLIGHTS > 0.001000000047497451305389404296875)\
    {\
        vec3 param_9 = output_color.xyz;\
        float luma_1 = getPerceptualBrightness(param_9);\
        vec4 _770 = output_color;\
        vec3 _780 = clamp(_770.xyz * (1.0 + (LIBRA_UBO_FRAGMENT_INSTANCE.PT_HIGHLIGHTS * luma_1)), vec3(0.0), vec3(1.0));\
        output_color.x = _780.x;\
        output_color.y = _780.y;\
        output_color.z = _780.z;\
    }\
    if (abs(LIBRA_UBO_FRAGMENT_INSTANCE.PT_SATURATION - 1.0) > 0.001000000047497451305389404296875)\
    {\
        vec3 param_10 = output_color.xyz;\
        float luma_2 = getPerceptualBrightness(param_10);\
        vec4 _801 = output_color;\
        vec3 _809 = clamp(mix(vec3(luma_2), _801.xyz, vec3(LIBRA_UBO_FRAGMENT_INSTANCE.PT_SATURATION)), vec3(0.0), vec3(1.0));\
        output_color.x = _809.x;\
        output_color.y = _809.y;\
        output_color.z = _809.z;\
    }\
    vec2 param_11 = gl_FragCoord.xy;\
    vec4 _825 = output_color;\
    vec3 _828 = _825.xyz + vec3((hash(param_11) - 0.5) / 255.0);\
    output_color.x = _828.x;\
    output_color.y = _828.y;\
    output_color.z = _828.z;\
    gl_FragData[0] = output_color;\
}\
\
",["frame_count_mod"]=0,["id"]="0",["mipmap_input"]=false,["parameters"]={{["description"]=" *  Turn ON Core > Color Correction & Interframe Blending",["id"]="NOTE2",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Motion enabled on latest RetroArch nightly build.",["id"]="NOTE3",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== MOTION == (OFF/ON)",["id"]="PT_ACCEL_ENABLE",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="      ↳ Tilt sensitivity",["id"]="PT_ACCEL_SENSITIVITY",["initial"]=1,["maximum"]=5,["minimum"]=0.1,["step"]=0.05,},{["description"]="      ↳ Brightness",["id"]="PT_BACKING_BRIGHTNESS",["initial"]=0.48,["maximum"]=0.65,["minimum"]=0.2,["step"]=0.01,},{["description"]="      ↳ Transparency amount",["id"]="PT_BASE_ALPHA",["initial"]=0.2,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="--- Gridline intensity (0=Less, 1=More)",["id"]="PT_BRIGHTNESS_GRID",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="--- Brightness mode (0=Simple, 1=Natural)",["id"]="PT_BRIGHTNESS_MODE",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="=== Pixel Transparency v2.2 === (OFF/ON)",["id"]="PT_ENABLE",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Append to any LCD shader as last pass. Try with GBC & GBA.",["id"]="PT_HIDE_CONTENT",["initial"]=0,["maximum"]=2,["minimum"]=0,["step"]=1,},{["description"]="--- Pixel brightness (0=OFF, -Dim / +Bright)",["id"]="PT_HIGHLIGHTS",["initial"]=0.05,["maximum"]=1,["minimum"]=-1,["step"]=0.01,},{["description"]="--- Backing tint (0=OFF, 1/2=Warm, 3/4=Neutral)",["id"]="PT_PALETTE",["initial"]=3,["maximum"]=4,["minimum"]=0,["step"]=1,},{["description"]="      ↳ Intensity",["id"]="PT_PALETTE_INTENSITY",["initial"]=1,["maximum"]=2,["minimum"]=0,["step"]=0.05,},{["description"]="--- Transparent pixels (0=White only, 1=Bright, 2=All)",["id"]="PT_PIXEL_MODE",["initial"]=1,["maximum"]=2,["minimum"]=0,["step"]=1,},{["description"]="--- Front polarizer tint (OFF/ON)",["id"]="PT_POLARIZER",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="      ↳ Intensity",["id"]="PT_POLARIZER_TINT",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="--- Color saturation",["id"]="PT_SATURATION",["initial"]=1,["maximum"]=1.5,["minimum"]=0.5,["step"]=0.05,},{["description"]="      ↳ Blur amount",["id"]="PT_SHADOW_BLUR",["initial"]=1,["maximum"]=5,["minimum"]=0,["step"]=0.1,},{["description"]="== SHADOWS == (OFF/ON)",["id"]="PT_SHADOW_ENABLE",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="      ↳ Shadow quality (0=Low, 1=High)",["id"]="PT_SHADOW_FAST_BLUR",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="          ↳ Max offset",["id"]="PT_SHADOW_MAX_OFFSET",["initial"]=2.5,["maximum"]=30,["minimum"]=0,["step"]=0.5,},{["description"]="      ↳ Shadow motion (OFF/ON) ",["id"]="PT_SHADOW_MOTION",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="          ↳ Neutral X",["id"]="PT_SHADOW_MOTION_X",["initial"]=2,["maximum"]=30,["minimum"]=-30,["step"]=0.5,},{["description"]="          ↳ Neutral Y",["id"]="PT_SHADOW_MOTION_Y",["initial"]=2,["maximum"]=30,["minimum"]=-30,["step"]=0.5,},{["description"]="      ↳ X offset",["id"]="PT_SHADOW_OFFSET_X",["initial"]=3,["maximum"]=30,["minimum"]=-30,["step"]=0.5,},{["description"]="      ↳ Y offset",["id"]="PT_SHADOW_OFFSET_Y",["initial"]=3,["maximum"]=30,["minimum"]=-30,["step"]=0.5,},{["description"]="      ↳ Opacity",["id"]="PT_SHADOW_OPACITY",["initial"]=0.5,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="--- White pixel detection threshold",["id"]="PT_THRESHOLD",["initial"]=0.9,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="--- Boost white pixel transparency (OFF/ON)",["id"]="PT_WHITE_BOOST",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="      ↳ Boost amount",["id"]="PT_WHITE_TRANSPARENCY",["initial"]=0.5,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="== COLOR ==",["id"]="SECTION1",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== TRANSPARENCY ==",["id"]="SECTION2",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== PERFORMANCE ==",["id"]="SECTION_PERF",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},{["index"]=0,["name"]="Original",["semantic"]="Original",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["size_uniforms"]={{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="unique",["name"]="PT_ACCEL_ENABLE",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_ACCEL_SENSITIVITY",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_MOTION",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_MAX_OFFSET",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_MOTION_X",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_MOTION_Y",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_OFFSET_X",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_OFFSET_Y",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_ENABLE",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_BRIGHTNESS_MODE",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_ENABLE",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_BLUR",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_OPACITY",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_THRESHOLD",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SHADOW_FAST_BLUR",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_PIXEL_MODE",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_BASE_ALPHA",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},{["index"]=0,["kind"]="unique",["name"]="Gyroscope",["semantic"]="Gyroscope",},{["index"]=0,["kind"]="unique",["name"]="Accelerometer",["semantic"]="Accelerometer",},{["index"]=0,["kind"]="unique",["name"]="AccelerometerRest",["semantic"]="AccelerometerRest",},{["index"]=0,["kind"]="unique",["name"]="PT_HIDE_CONTENT",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_PALETTE",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_PALETTE_INTENSITY",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_BACKING_BRIGHTNESS",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_POLARIZER",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_POLARIZER_TINT",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_SATURATION",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_HIGHLIGHTS",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_WHITE_BOOST",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_WHITE_TRANSPARENCY",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="PT_BRIGHTNESS_GRID",["semantic"]="FloatParameter",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
\
struct LIBRA_UBO_VERTEX\
{\
    mat4 MVP;\
    vec3 Gyroscope;\
    vec3 Accelerometer;\
    vec3 AccelerometerRest;\
    float PT_HIDE_CONTENT;\
    float PT_PALETTE;\
    float PT_PALETTE_INTENSITY;\
    float PT_BACKING_BRIGHTNESS;\
    float PT_POLARIZER;\
    float PT_POLARIZER_TINT;\
    float PT_SATURATION;\
    float PT_HIGHLIGHTS;\
    float PT_WHITE_BOOST;\
    float PT_WHITE_TRANSPARENCY;\
    float PT_BRIGHTNESS_GRID;\
};\
\
uniform LIBRA_UBO_VERTEX LIBRA_UBO_VERTEX_INSTANCE;\
\
struct LIBRA_PUSH_VERTEX\
{\
    vec4 SourceSize;\
    vec4 OutputSize;\
    float PT_ACCEL_ENABLE;\
    float PT_ACCEL_SENSITIVITY;\
    float PT_SHADOW_MOTION;\
    float PT_SHADOW_MAX_OFFSET;\
    float PT_SHADOW_MOTION_X;\
    float PT_SHADOW_MOTION_Y;\
    float PT_SHADOW_OFFSET_X;\
    float PT_SHADOW_OFFSET_Y;\
    float PT_ENABLE;\
    float PT_BRIGHTNESS_MODE;\
    float PT_SHADOW_ENABLE;\
    float PT_SHADOW_BLUR;\
    float PT_SHADOW_OPACITY;\
    float PT_THRESHOLD;\
    float PT_SHADOW_FAST_BLUR;\
    float PT_PIXEL_MODE;\
    float PT_BASE_ALPHA;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
varying vec2 LIBRA_VARYING_1;\
varying float LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
\
vec2 getOrientedTilt(vec3 accel)\
{\
    float magnitude = length(accel);\
    if (magnitude < 0.00999999977648258209228515625)\
    {\
        return vec2(0.0);\
    }\
    vec3 dir = accel / vec3(magnitude);\
    return vec2(-dir.x, dir.y);\
}\
\
void main()\
{\
    gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
    LIBRA_VARYING_0 = TexCoord;\
    LIBRA_VARYING_1 = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.zw;\
    float scale_x = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.x / 640.0;\
    float scale_y = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.y / 480.0;\
    LIBRA_VARYING_2 = sqrt(scale_x * scale_y);\
    vec2 gravity = vec2(0.0);\
    bool has_sensors = false;\
    if (LIBRA_PUSH_VERTEX_INSTANCE.PT_ACCEL_ENABLE > 0.5)\
    {\
        vec3 accel = LIBRA_UBO_VERTEX_INSTANCE.Accelerometer;\
        has_sensors = length(accel) > 0.00999999977648258209228515625;\
        if (has_sensors)\
        {\
            vec3 param = accel;\
            gravity = getOrientedTilt(param);\
            gravity = clamp(gravity * LIBRA_PUSH_VERTEX_INSTANCE.PT_ACCEL_SENSITIVITY, vec2(-1.0), vec2(1.0));\
        }\
    }\
    bool _132 = LIBRA_PUSH_VERTEX_INSTANCE.PT_SHADOW_MOTION > 0.5;\
    bool _138;\
    if (_132)\
    {\
        _138 = LIBRA_PUSH_VERTEX_INSTANCE.PT_ACCEL_ENABLE > 0.5;\
    }\
    else\
    {\
        _138 = _132;\
    }\
    if (_138 && has_sensors)\
    {\
        vec2 base = vec2(LIBRA_PUSH_VERTEX_INSTANCE.PT_SHADOW_MOTION_X, LIBRA_PUSH_VERTEX_INSTANCE.PT_SHADOW_MOTION_Y);\
        LIBRA_VARYING_3 = base + (gravity * LIBRA_PUSH_VERTEX_INSTANCE.PT_SHADOW_MAX_OFFSET);\
    }\
    else\
    {\
        LIBRA_VARYING_3 = vec2(LIBRA_PUSH_VERTEX_INSTANCE.PT_SHADOW_OFFSET_X, LIBRA_PUSH_VERTEX_INSTANCE.PT_SHADOW_OFFSET_Y);\
    }\
}\
\
",["wrap_mode"]="clamp_to_border",},},["textures"]={},}
