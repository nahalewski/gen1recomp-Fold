return {["parameter_overrides"]={{["name"]="response_time",["value"]=0.33,},},["pass_count"]=5,["passes"]={{["alias"]="PASS0",["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
\
struct ResType\
{\
    vec2 _m0;\
    vec2 _m1;\
};\
\
struct LIBRA_UBO_FRAGMENT\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_FRAGMENT LIBRA_UBO_FRAGMENT_INSTANCE;\
\
struct LIBRA_PUSH_FRAGMENT\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
    vec4 OriginalHistorySize1;\
    float color_toggle;\
    float pixel_size;\
    float pixel_softness;\
    float sharpening_amount;\
    float integer_mode;\
    float video_scale;\
    float baseline_alpha;\
    float grey_balance;\
    float response_time;\
    float brightness_mode;\
    float sharp_mode;\
    float pixel_shape;\
    float palette;\
    float auto_soften;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory1;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory2;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory3;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory4;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory5;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory6;\
uniform sampler2D LIBRA_TEXTURE_OriginalHistory7;\
uniform sampler2D LIBRA_TEXTURE_COLOR_PALETTE;\
\
varying vec2 LIBRA_VARYING_0;\
varying vec2 LIBRA_VARYING_9;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_4;\
varying vec2 LIBRA_VARYING_5;\
varying vec2 LIBRA_VARYING_6;\
varying float LIBRA_VARYING_11;\
varying float LIBRA_VARYING_10;\
\
float intersect_line_segment(float pixel_start, float pixel_end, float dot_start, float dot_end)\
{\
    float overlap_start = max(pixel_start, dot_start);\
    float overlap_end = min(pixel_end, dot_end);\
    return max(overlap_end - overlap_start, 0.0);\
}\
\
float intersect_rect_area(vec4 px_square, vec4 rect)\
{\
    vec2 bl = max(px_square.xy, rect.xy);\
    vec2 tr = min(px_square.zw, rect.zw);\
    vec2 coverage = max(tr - bl, vec2(0.0));\
    return coverage.x * coverage.y;\
}\
\
void main()\
{\
    vec2 final_tex_coord = LIBRA_VARYING_0;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.integer_mode > 0.5)\
    {\
        vec2 centered_coord = abs(LIBRA_VARYING_0 - vec2(0.5));\
        bool _96 = centered_coord.x > (LIBRA_VARYING_9.x * 0.5);\
        bool _106;\
        if (!_96)\
        {\
            _106 = centered_coord.y > (LIBRA_VARYING_9.y * 0.5);\
        }\
        else\
        {\
            _106 = _96;\
        }\
        if (_106)\
        {\
            gl_FragData[0] = vec4(0.0);\
            return;\
        }\
        final_tex_coord = ((LIBRA_VARYING_0 - vec2(0.5)) / LIBRA_VARYING_9) + vec2(0.5);\
    }\
    vec3 foreground_source = texture2D(LIBRA_TEXTURE_Source, final_tex_coord).xyz;\
    vec3 curr_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_Source, final_tex_coord).xyz);\
    vec3 prev0_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory1, final_tex_coord).xyz);\
    vec3 prev1_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory2, final_tex_coord).xyz);\
    vec3 prev2_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory3, final_tex_coord).xyz);\
    vec3 prev3_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory4, final_tex_coord).xyz);\
    vec3 prev4_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory5, final_tex_coord).xyz);\
    vec3 prev5_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory6, final_tex_coord).xyz);\
    vec3 prev6_rgb = abs(vec3(1.0) - texture2D(LIBRA_TEXTURE_OriginalHistory7, final_tex_coord).xyz);\
    float is_on_dot = 0.0;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.integer_mode > 0.5)\
    {\
        bool _218 = mod(final_tex_coord.x, LIBRA_VARYING_2.x) > LIBRA_VARYING_3.x;\
        bool _229;\
        if (_218)\
        {\
            _229 = mod(final_tex_coord.y, LIBRA_VARYING_2.y) > LIBRA_VARYING_3.y;\
        }\
        else\
        {\
            _229 = _218;\
        }\
        if (_229)\
        {\
            is_on_dot = 1.0;\
        }\
    }\
    else\
    {\
        ResType _238;\
        _238._m1 = vec2(ivec2(LIBRA_VARYING_4));\
        _238._m0 = LIBRA_VARYING_4 - _238._m1;\
        vec2 tx_coord_i = _238._m1;\
        vec2 tx_coord_f = _238._m0;\
        vec2 pixel_center = (tx_coord_f - vec2(0.5)) * LIBRA_VARYING_5;\
        vec4 pixel_rect = vec4(pixel_center - (LIBRA_VARYING_5 * 0.5), pixel_center + (LIBRA_VARYING_5 * 0.5));\
        vec4 dot_rect = vec4((-LIBRA_VARYING_6) * 0.5, LIBRA_VARYING_6 * 0.5);\
        float param = pixel_rect.x;\
        float param_1 = pixel_rect.z;\
        float param_2 = dot_rect.x;\
        float param_3 = dot_rect.z;\
        float x_coverage = intersect_line_segment(param, param_1, param_2, param_3) / LIBRA_VARYING_5.x;\
        float param_4 = pixel_rect.y;\
        float param_5 = pixel_rect.w;\
        float param_6 = dot_rect.y;\
        float param_7 = dot_rect.w;\
        float y_coverage = intersect_line_segment(param_4, param_5, param_6, param_7) / LIBRA_VARYING_5.y;\
        float rect_linear = x_coverage * y_coverage;\
        float rect_sharpened;\
        if (LIBRA_PUSH_FRAGMENT_INSTANCE.sharp_mode < 0.5)\
        {\
            float sharp_factor = 1.0 / max(LIBRA_VARYING_11, 0.001000000047497451305389404296875);\
            rect_sharpened = pow(x_coverage, sharp_factor) * pow(y_coverage, sharp_factor);\
        }\
        else\
        {\
            float sigmoid_strength = 10.0 / max(LIBRA_VARYING_11, 0.001000000047497451305389404296875);\
            float x_sharp = 1.0 / (1.0 + exp((-sigmoid_strength) * (x_coverage - 0.5)));\
            float y_sharp = 1.0 / (1.0 + exp((-sigmoid_strength) * (y_coverage - 0.5)));\
            rect_sharpened = x_sharp * y_sharp;\
        }\
        float rect_coverage = mix(rect_linear, rect_sharpened, LIBRA_PUSH_FRAGMENT_INSTANCE.sharpening_amount);\
        vec4 param_8 = pixel_rect;\
        vec4 param_9 = dot_rect;\
        float circ_linear = intersect_rect_area(param_8, param_9) / (LIBRA_VARYING_5.x * LIBRA_VARYING_5.y);\
        float circ_sharpened;\
        if (LIBRA_PUSH_FRAGMENT_INSTANCE.sharp_mode < 0.5)\
        {\
            circ_sharpened = pow(circ_linear, 1.0 / max(LIBRA_VARYING_11, 0.001000000047497451305389404296875));\
        }\
        else\
        {\
            float sigmoid_strength_1 = 10.0 / max(LIBRA_VARYING_11, 0.001000000047497451305389404296875);\
            circ_sharpened = 1.0 / (1.0 + exp((-sigmoid_strength_1) * (circ_linear - 0.5)));\
        }\
        float circ_coverage = mix(circ_linear, circ_sharpened, LIBRA_PUSH_FRAGMENT_INSTANCE.sharpening_amount);\
        is_on_dot = mix(circ_coverage, rect_coverage, LIBRA_PUSH_FRAGMENT_INSTANCE.pixel_shape);\
    }\
    vec3 input_rgb = curr_rgb;\
    input_rgb += ((prev0_rgb - input_rgb) * LIBRA_PUSH_FRAGMENT_INSTANCE.response_time);\
    input_rgb += ((prev1_rgb - input_rgb) * pow(LIBRA_PUSH_FRAGMENT_INSTANCE.response_time, 2.0));\
    input_rgb += ((prev2_rgb - input_rgb) * pow(LIBRA_PUSH_FRAGMENT_INSTANCE.response_time, 3.0));\
    input_rgb += ((prev3_rgb - input_rgb) * pow(LIBRA_PUSH_FRAGMENT_INSTANCE.response_time, 4.0));\
    input_rgb += ((prev4_rgb - input_rgb) * pow(LIBRA_PUSH_FRAGMENT_INSTANCE.response_time, 5.0));\
    input_rgb += ((prev5_rgb - input_rgb) * pow(LIBRA_PUSH_FRAGMENT_INSTANCE.response_time, 6.0));\
    input_rgb += ((prev6_rgb - input_rgb) * pow(LIBRA_PUSH_FRAGMENT_INSTANCE.response_time, 7.0));\
    float brightness;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.brightness_mode < 0.5)\
    {\
        brightness = (input_rgb.x + input_rgb.y) + input_rgb.z;\
    }\
    else\
    {\
        brightness = ((0.2125999927520751953125 * input_rgb.x) + (0.715200006961822509765625 * input_rgb.y)) + (0.072200000286102294921875 * input_rgb.z);\
    }\
    float grey_balance_adjusted = LIBRA_PUSH_FRAGMENT_INSTANCE.grey_balance / LIBRA_VARYING_10;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.brightness_mode >= 0.5)\
    {\
        grey_balance_adjusted /= 3.0;\
    }\
    float rgb_to_alpha = (brightness / grey_balance_adjusted) + LIBRA_PUSH_FRAGMENT_INSTANCE.baseline_alpha;\
    vec3 foreground_color;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 0.5)\
    {\
        foreground_color = texture2D(LIBRA_TEXTURE_COLOR_PALETTE, vec2(0.75, 0.5)).xyz;\
    }\
    else\
    {\
        if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 1.5)\
        {\
            foreground_color = vec3(0.0670000016689300537109375, 0.097999997437000274658203125, 0.13300000131130218505859375);\
        }\
        else\
        {\
            if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 2.5)\
            {\
                foreground_color = vec3(0.125);\
            }\
            else\
            {\
                if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 3.5)\
                {\
                    foreground_color = vec3(0.0);\
                }\
                else\
                {\
                    if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 4.5)\
                    {\
                        foreground_color = vec3(0.114000000059604644775390625, 0.41600000858306884765625, 0.4199999868869781494140625);\
                    }\
                    else\
                    {\
                        if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 5.5)\
                        {\
                            foreground_color = vec3(0.0, 0.324999988079071044921875, 0.20000000298023223876953125);\
                        }\
                        else\
                        {\
                            foreground_color = vec3(0.0, 0.324999988079071044921875, 0.31400001049041748046875);\
                        }\
                    }\
                }\
            }\
        }\
    }\
    vec4 out_color;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.color_toggle == 0.0)\
    {\
        out_color = vec4(foreground_color, rgb_to_alpha);\
    }\
    else\
    {\
        out_color = vec4(foreground_source, rgb_to_alpha);\
    }\
    out_color.w *= is_on_dot;\
    gl_FragData[0] = out_color;\
}\
\
",["frame_count_mod"]=0,["id"]="0",["mipmap_input"]=false,["parameters"]={{["description"]="=== GAME BOY DOT MATRIX SHADER v1.2 ===",["id"]="GAMEBOY_SHADER",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== LCD effects ==",["id"]="LCD_EFFECTS",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Turn OFF Integer Scale in Settings > Video > Scaling",["id"]="NOTE1",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  GBC: Turn OFF Core > Color Correction & Interframe Blending",["id"]="NOTE2",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  GBA: Turn ON Core > Color Correction & Interframe Blending",["id"]="NOTE3",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Soft / circular pixels = less grid distortion",["id"]="NOTE5",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Screen position ==",["id"]="SCREEN_POSITIONING",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Blend amount",["id"]="adjacent_texel_alpha_blending",["initial"]=0.1755,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="         ↳ Auto soften (reduce distortion)",["id"]="auto_soften",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Base pixel transparency",["id"]="baseline_alpha",["initial"]=0.1,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="     ↳ Background texture smoothing",["id"]="bg_smoothing",["initial"]=0.75,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="== Pixel blending mode == (0=Blend gaps, 1=Blend all)",["id"]="blending_mode",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Pixel transparency detection == (0=Simple, 1=Perceptual)",["id"]="brightness_mode",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Color mode == (0=Grayscale, 1=Color)",["id"]="color_toggle",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Contrast",["id"]="contrast",["initial"]=0.95,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Grey balance",["id"]="grey_balance",["initial"]=3,["maximum"]=4,["minimum"]=0,["step"]=0.1,},{["description"]="== Display mode == (0=Full, 1=Pixel Perfect, 2=Scale factor)",["id"]="integer_mode",["initial"]=0,["maximum"]=2,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Palette (0=IMG, 1/2=Pocket, 3=B&W, 4=DMG, 5/6=Light)",["id"]="palette",["initial"]=0,["maximum"]=6,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Pixel opacity",["id"]="pixel_opacity",["initial"]=1,["maximum"]=1,["minimum"]=0.01,["step"]=0.01,},{["description"]="     ↳ Pixel shape [Sharp mode] (Circle/Rectangle)",["id"]="pixel_shape",["initial"]=1,["maximum"]=1.3,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Pixel size",["id"]="pixel_size",["initial"]=0.8,["maximum"]=1.1,["minimum"]=0.2,["step"]=0.05,},{["description"]="     ↳ Pixel softness",["id"]="pixel_softness",["initial"]=1,["maximum"]=5,["minimum"]=0.2,["step"]=0.05,},{["description"]="     ↳ Latency",["id"]="response_time",["initial"]=0,["maximum"]=0.777,["minimum"]=0,["step"]=0.111,},{["description"]="     ↳ Screen light",["id"]="screen_light",["initial"]=1,["maximum"]=2,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Screen offset horizontal",["id"]="screen_offset_x",["initial"]=0,["maximum"]=5,["minimum"]=-5,["step"]=1,},{["description"]="     ↳ Screen offset vertical",["id"]="screen_offset_y",["initial"]=0,["maximum"]=5,["minimum"]=-5,["step"]=1,},{["description"]="== Drop shadows == (OFF/ON)",["id"]="shadow_enable",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="         ↳ Max offset",["id"]="shadow_max_offset",["initial"]=2.5,["maximum"]=30,["minimum"]=0,["step"]=0.5,},{["description"]="     ↳ Shadow motion (OFF/ON)",["id"]="shadow_motion",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Shadow offset horizontal",["id"]="shadow_offset_x",["initial"]=1,["maximum"]=5,["minimum"]=-5,["step"]=0.5,},{["description"]="     ↳ Shadow offset vertical",["id"]="shadow_offset_y",["initial"]=1,["maximum"]=5,["minimum"]=-5,["step"]=0.5,},{["description"]="     ↳ Shadow opacity",["id"]="shadow_opacity",["initial"]=0.55,["maximum"]=1,["minimum"]=0.01,["step"]=0.01,},{["description"]="== Fullscreen pixels == (0=Soft, 1=Sharp)",["id"]="sharp_mode",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Pixel edge sharpness",["id"]="sharpening_amount",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Scale factor",["id"]="video_scale",["initial"]=5,["maximum"]=15,["minimum"]=2,["step"]=1,},},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},{["index"]=1,["name"]="OriginalHistory1",["semantic"]="OriginalHistory",},{["index"]=2,["name"]="OriginalHistory2",["semantic"]="OriginalHistory",},{["index"]=3,["name"]="OriginalHistory3",["semantic"]="OriginalHistory",},{["index"]=4,["name"]="OriginalHistory4",["semantic"]="OriginalHistory",},{["index"]=5,["name"]="OriginalHistory5",["semantic"]="OriginalHistory",},{["index"]=6,["name"]="OriginalHistory6",["semantic"]="OriginalHistory",},{["index"]=7,["name"]="OriginalHistory7",["semantic"]="OriginalHistory",},{["index"]=0,["name"]="COLOR_PALETTE",["semantic"]="User",["user_name"]="COLOR_PALETTE",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["size_uniforms"]={{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=1,["kind"]="texture",["name"]="OriginalHistorySize1",["semantic"]="OriginalHistory",},{["index"]=0,["kind"]="unique",["name"]="color_toggle",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="pixel_size",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="pixel_softness",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="sharpening_amount",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="integer_mode",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="video_scale",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="baseline_alpha",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="grey_balance",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="response_time",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="brightness_mode",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="sharp_mode",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="pixel_shape",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="palette",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="auto_soften",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
\
struct LIBRA_UBO_VERTEX\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_VERTEX LIBRA_UBO_VERTEX_INSTANCE;\
\
struct LIBRA_PUSH_VERTEX\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
    vec4 OriginalHistorySize1;\
    float color_toggle;\
    float pixel_size;\
    float pixel_softness;\
    float sharpening_amount;\
    float integer_mode;\
    float video_scale;\
    float baseline_alpha;\
    float grey_balance;\
    float response_time;\
    float brightness_mode;\
    float sharp_mode;\
    float pixel_shape;\
    float palette;\
    float auto_soften;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
varying vec2 LIBRA_VARYING_9;\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_4;\
varying vec2 LIBRA_VARYING_5;\
varying vec2 LIBRA_VARYING_6;\
varying float LIBRA_VARYING_11;\
varying float LIBRA_VARYING_10;\
float video_scale_factor;\
vec2 original_coord;\
vec2 screen_bounds;\
\
float intersect_line_segment(float pixel_start, float pixel_end, float dot_start, float dot_end)\
{\
    float overlap_start = max(pixel_start, dot_start);\
    float overlap_end = min(pixel_end, dot_end);\
    return max(overlap_end - overlap_start, 0.0);\
}\
\
float intersect_rect_area(vec4 px_square, vec4 rect)\
{\
    vec2 bl = max(px_square.xy, rect.xy);\
    vec2 tr = min(px_square.zw, rect.zw);\
    vec2 coverage = max(tr - bl, vec2(0.0));\
    return coverage.x * coverage.y;\
}\
\
float calculate_coverage_at_point(vec2 tx_coord_f, float pixel_size, float pixel_softness, float sharpening_amount, float pixel_shape, float sharp_mode)\
{\
    vec2 pixel_center = tx_coord_f - vec2(0.5);\
    vec4 pixel_rect = vec4(pixel_center - vec2(0.5), pixel_center + vec2(0.5));\
    vec2 dot_size_in_px = vec2(pixel_size);\
    vec4 dot_rect = vec4((-dot_size_in_px) * 0.5, dot_size_in_px * 0.5);\
    float param = pixel_rect.x;\
    float param_1 = pixel_rect.z;\
    float param_2 = dot_rect.x;\
    float param_3 = dot_rect.z;\
    float x_coverage = intersect_line_segment(param, param_1, param_2, param_3);\
    float param_4 = pixel_rect.y;\
    float param_5 = pixel_rect.w;\
    float param_6 = dot_rect.y;\
    float param_7 = dot_rect.w;\
    float y_coverage = intersect_line_segment(param_4, param_5, param_6, param_7);\
    float rect_linear = x_coverage * y_coverage;\
    float rect_sharpened;\
    if (sharp_mode < 0.5)\
    {\
        float sharp_factor = 1.0 / max(pixel_softness, 0.001000000047497451305389404296875);\
        rect_sharpened = pow(x_coverage, sharp_factor) * pow(y_coverage, sharp_factor);\
    }\
    else\
    {\
        float sigmoid_strength = 10.0 / max(pixel_softness, 0.001000000047497451305389404296875);\
        float x_sharp = 1.0 / (1.0 + exp((-sigmoid_strength) * (x_coverage - 0.5)));\
        float y_sharp = 1.0 / (1.0 + exp((-sigmoid_strength) * (y_coverage - 0.5)));\
        rect_sharpened = x_sharp * y_sharp;\
    }\
    float rect_coverage = mix(rect_linear, rect_sharpened, sharpening_amount);\
    vec4 param_8 = pixel_rect;\
    vec4 param_9 = dot_rect;\
    float circ_linear = intersect_rect_area(param_8, param_9);\
    float circ_sharpened;\
    if (sharp_mode < 0.5)\
    {\
        circ_sharpened = pow(circ_linear, 1.0 / max(pixel_softness, 0.001000000047497451305389404296875));\
    }\
    else\
    {\
        float sigmoid_strength_1 = 10.0 / max(pixel_softness, 0.001000000047497451305389404296875);\
        circ_sharpened = 1.0 / (1.0 + exp((-sigmoid_strength_1) * (circ_linear - 0.5)));\
    }\
    float circ_coverage = mix(circ_linear, circ_sharpened, sharpening_amount);\
    return mix(circ_coverage, rect_coverage, pixel_shape);\
}\
\
float sample_average_coverage(float pixel_size, float pixel_softness, float sharpening_amount, float pixel_shape, float sharp_mode)\
{\
    float total = 0.0;\
    for (int y = 0; y < 4; y++)\
    {\
        for (int x = 0; x < 4; x++)\
        {\
            vec2 sample_pos = vec2((-0.375) + (float(x) * 0.25), (-0.375) + (float(y) * 0.25));\
            vec2 param = sample_pos;\
            float param_1 = pixel_size;\
            float param_2 = pixel_softness;\
            float param_3 = sharpening_amount;\
            float param_4 = pixel_shape;\
            float param_5 = sharp_mode;\
            total += calculate_coverage_at_point(param, param_1, param_2, param_3, param_4, param_5);\
        }\
    }\
    return total / 16.0;\
}\
\
void main()\
{\
    if (LIBRA_PUSH_VERTEX_INSTANCE.integer_mode > 0.5)\
    {\
        if (LIBRA_PUSH_VERTEX_INSTANCE.integer_mode > 1.5)\
        {\
            video_scale_factor = LIBRA_PUSH_VERTEX_INSTANCE.video_scale;\
        }\
        else\
        {\
            video_scale_factor = floor(LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.y * LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.w);\
        }\
        vec2 scaled_video_out = LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.xy * vec2(video_scale_factor);\
        LIBRA_VARYING_9 = scaled_video_out / LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.xy;\
        gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
        LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;\
        original_coord = TexCoord;\
        LIBRA_VARYING_2 = LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
        LIBRA_VARYING_3 = vec2(1.0) / (LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.xy * video_scale_factor);\
        screen_bounds = LIBRA_VARYING_9;\
        LIBRA_VARYING_4 = vec2(0.0);\
        LIBRA_VARYING_5 = vec2(0.0);\
        LIBRA_VARYING_6 = vec2(0.0);\
    }\
    else\
    {\
        video_scale_factor = 1.0;\
        LIBRA_VARYING_9 = vec2(1.0);\
        gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
        LIBRA_VARYING_0 = TexCoord;\
        original_coord = TexCoord;\
        LIBRA_VARYING_4 = TexCoord * LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.xy;\
        LIBRA_VARYING_5 = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.xy / LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.xy;\
        LIBRA_VARYING_6 = LIBRA_VARYING_5 * LIBRA_PUSH_VERTEX_INSTANCE.pixel_size;\
        LIBRA_VARYING_2 = vec2(0.0);\
        LIBRA_VARYING_3 = vec2(0.0);\
        screen_bounds = vec2(1.0);\
    }\
    LIBRA_VARYING_11 = LIBRA_PUSH_VERTEX_INSTANCE.pixel_softness;\
    bool _417 = LIBRA_PUSH_VERTEX_INSTANCE.auto_soften > 0.5;\
    bool _423;\
    if (_417)\
    {\
        _423 = LIBRA_PUSH_VERTEX_INSTANCE.integer_mode < 0.5;\
    }\
    else\
    {\
        _423 = _417;\
    }\
    if (_423)\
    {\
        vec2 scale = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.xy / LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.xy;\
        vec2 fract_scale = fract(scale);\
        float fract_factor = max(0.5 - abs(fract_scale.x - 0.5), 0.5 - abs(fract_scale.y - 0.5));\
        LIBRA_VARYING_11 += (fract_factor * 4.0);\
    }\
    if (LIBRA_PUSH_VERTEX_INSTANCE.integer_mode < 0.5)\
    {\
        float param = 0.800000011920928955078125;\
        float param_1 = 0.800000011920928955078125;\
        float param_2 = 1.0;\
        float param_3 = 1.0;\
        float param_4 = LIBRA_PUSH_VERTEX_INSTANCE.sharp_mode;\
        float ref_brightness = sample_average_coverage(param, param_1, param_2, param_3, param_4);\
        float param_5 = LIBRA_PUSH_VERTEX_INSTANCE.pixel_size;\
        float param_6 = LIBRA_VARYING_11;\
        float param_7 = LIBRA_PUSH_VERTEX_INSTANCE.sharpening_amount;\
        float param_8 = LIBRA_PUSH_VERTEX_INSTANCE.pixel_shape;\
        float param_9 = LIBRA_PUSH_VERTEX_INSTANCE.sharp_mode;\
        float cur_brightness = sample_average_coverage(param_5, param_6, param_7, param_8, param_9);\
        float _492;\
        if (LIBRA_PUSH_VERTEX_INSTANCE.sharp_mode < 0.5)\
        {\
            _492 = 2.7999999523162841796875;\
        }\
        else\
        {\
            _492 = mix(2.5, 1.60000002384185791015625, LIBRA_PUSH_VERTEX_INSTANCE.pixel_shape);\
        }\
        float base_comp = _492;\
        float brightness_ratio = ref_brightness / max(cur_brightness, 0.001000000047497451305389404296875);\
        float _512;\
        if (LIBRA_PUSH_VERTEX_INSTANCE.pixel_size > 0.800000011920928955078125)\
        {\
            _512 = pow(LIBRA_PUSH_VERTEX_INSTANCE.pixel_size / 0.800000011920928955078125, 0.62000000476837158203125);\
        }\
        else\
        {\
            _512 = 1.0;\
        }\
        float size_comp = _512;\
        float _525;\
        if (LIBRA_VARYING_11 > 1.0)\
        {\
            _525 = pow(LIBRA_VARYING_11, 0.4440000057220458984375);\
        }\
        else\
        {\
            _525 = 1.0;\
        }\
        float softness_comp = _525;\
        float _537;\
        if (LIBRA_PUSH_VERTEX_INSTANCE.sharp_mode < 0.5)\
        {\
            _537 = mix(0.85699999332427978515625, 1.0, LIBRA_PUSH_VERTEX_INSTANCE.sharpening_amount);\
        }\
        else\
        {\
            _537 = mix(1.5, 1.0, LIBRA_PUSH_VERTEX_INSTANCE.sharpening_amount);\
        }\
        float sharpening_comp = _537;\
        bool _552 = LIBRA_PUSH_VERTEX_INSTANCE.sharp_mode >= 0.5;\
        bool _558;\
        if (_552)\
        {\
            _558 = LIBRA_PUSH_VERTEX_INSTANCE.pixel_shape > 1.0;\
        }\
        else\
        {\
            _558 = _552;\
        }\
        float _559;\
        if (_558)\
        {\
            _559 = 1.0 + ((LIBRA_PUSH_VERTEX_INSTANCE.pixel_shape - 1.0) * 0.666999995708465576171875);\
        }\
        else\
        {\
            _559 = 1.0;\
        }\
        float shape_comp = _559;\
        LIBRA_VARYING_10 = ((((base_comp * brightness_ratio) * size_comp) * softness_comp) * sharpening_comp) * shape_comp;\
    }\
    else\
    {\
        LIBRA_VARYING_10 = 1.0;\
    }\
}\
\
",["wrap_mode"]="clamp_to_border",},{["alias"]="PASS1",["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
\
struct LIBRA_UBO_FRAGMENT\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_FRAGMENT LIBRA_UBO_FRAGMENT_INSTANCE;\
\
struct LIBRA_PUSH_FRAGMENT\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
    float blending_mode;\
    float adjacent_texel_alpha_blending;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_6;\
varying vec2 LIBRA_VARYING_7;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_4;\
varying vec2 LIBRA_VARYING_5;\
\
float blending_modifier(float color)\
{\
    float blend_bool = float(int(color == 0.0));\
    return clamp(blend_bool + LIBRA_PUSH_FRAGMENT_INSTANCE.blending_mode, 0.0, 1.0);\
}\
\
void main()\
{\
    vec4 out_color = texture2D(LIBRA_TEXTURE_Source, LIBRA_VARYING_0);\
    vec2 blur_coords_up_clamped = clamp(LIBRA_VARYING_2, LIBRA_VARYING_6, LIBRA_VARYING_7);\
    vec2 blur_coords_down_clamped = clamp(LIBRA_VARYING_3, LIBRA_VARYING_6, LIBRA_VARYING_7);\
    vec2 blur_coords_right_clamped = clamp(LIBRA_VARYING_4, LIBRA_VARYING_6, LIBRA_VARYING_7);\
    vec2 blur_coords_left_clamped = clamp(LIBRA_VARYING_5, LIBRA_VARYING_6, LIBRA_VARYING_7);\
    vec4 adjacent_texel_1 = texture2D(LIBRA_TEXTURE_Source, blur_coords_up_clamped);\
    vec4 adjacent_texel_2 = texture2D(LIBRA_TEXTURE_Source, blur_coords_down_clamped);\
    vec4 adjacent_texel_3 = texture2D(LIBRA_TEXTURE_Source, blur_coords_right_clamped);\
    vec4 adjacent_texel_4 = texture2D(LIBRA_TEXTURE_Source, blur_coords_left_clamped);\
    float param = out_color.w;\
    out_color.w -= ((((((out_color.w - adjacent_texel_1.w) + (out_color.w - adjacent_texel_2.w)) + (out_color.w - adjacent_texel_3.w)) + (out_color.w - adjacent_texel_4.w)) * LIBRA_PUSH_FRAGMENT_INSTANCE.adjacent_texel_alpha_blending) * blending_modifier(param));\
    gl_FragData[0] = out_color;\
}\
\
",["frame_count_mod"]=0,["id"]="1",["mipmap_input"]=false,["parameters"]={{["description"]="=== GAME BOY DOT MATRIX SHADER v1.2 ===",["id"]="GAMEBOY_SHADER",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== LCD effects ==",["id"]="LCD_EFFECTS",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Turn OFF Integer Scale in Settings > Video > Scaling",["id"]="NOTE1",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  GBC: Turn OFF Core > Color Correction & Interframe Blending",["id"]="NOTE2",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  GBA: Turn ON Core > Color Correction & Interframe Blending",["id"]="NOTE3",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Soft / circular pixels = less grid distortion",["id"]="NOTE5",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Screen position ==",["id"]="SCREEN_POSITIONING",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Blend amount",["id"]="adjacent_texel_alpha_blending",["initial"]=0.1755,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="         ↳ Auto soften (reduce distortion)",["id"]="auto_soften",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Base pixel transparency",["id"]="baseline_alpha",["initial"]=0.1,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="     ↳ Background texture smoothing",["id"]="bg_smoothing",["initial"]=0.75,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="== Pixel blending mode == (0=Blend gaps, 1=Blend all)",["id"]="blending_mode",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Pixel transparency detection == (0=Simple, 1=Perceptual)",["id"]="brightness_mode",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Color mode == (0=Grayscale, 1=Color)",["id"]="color_toggle",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Contrast",["id"]="contrast",["initial"]=0.95,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Grey balance",["id"]="grey_balance",["initial"]=3,["maximum"]=4,["minimum"]=0,["step"]=0.1,},{["description"]="== Display mode == (0=Full, 1=Pixel Perfect, 2=Scale factor)",["id"]="integer_mode",["initial"]=0,["maximum"]=2,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Palette (0=IMG, 1/2=Pocket, 3=B&W, 4=DMG, 5/6=Light)",["id"]="palette",["initial"]=0,["maximum"]=6,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Pixel opacity",["id"]="pixel_opacity",["initial"]=1,["maximum"]=1,["minimum"]=0.01,["step"]=0.01,},{["description"]="     ↳ Pixel shape [Sharp mode] (Circle/Rectangle)",["id"]="pixel_shape",["initial"]=1,["maximum"]=1.3,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Pixel size",["id"]="pixel_size",["initial"]=0.8,["maximum"]=1.1,["minimum"]=0.2,["step"]=0.05,},{["description"]="     ↳ Pixel softness",["id"]="pixel_softness",["initial"]=1,["maximum"]=5,["minimum"]=0.2,["step"]=0.05,},{["description"]="     ↳ Latency",["id"]="response_time",["initial"]=0,["maximum"]=0.777,["minimum"]=0,["step"]=0.111,},{["description"]="     ↳ Screen light",["id"]="screen_light",["initial"]=1,["maximum"]=2,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Screen offset horizontal",["id"]="screen_offset_x",["initial"]=0,["maximum"]=5,["minimum"]=-5,["step"]=1,},{["description"]="     ↳ Screen offset vertical",["id"]="screen_offset_y",["initial"]=0,["maximum"]=5,["minimum"]=-5,["step"]=1,},{["description"]="== Drop shadows == (OFF/ON)",["id"]="shadow_enable",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="         ↳ Max offset",["id"]="shadow_max_offset",["initial"]=2.5,["maximum"]=30,["minimum"]=0,["step"]=0.5,},{["description"]="     ↳ Shadow motion (OFF/ON)",["id"]="shadow_motion",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Shadow offset horizontal",["id"]="shadow_offset_x",["initial"]=1,["maximum"]=5,["minimum"]=-5,["step"]=0.5,},{["description"]="     ↳ Shadow offset vertical",["id"]="shadow_offset_y",["initial"]=1,["maximum"]=5,["minimum"]=-5,["step"]=0.5,},{["description"]="     ↳ Shadow opacity",["id"]="shadow_opacity",["initial"]=0.55,["maximum"]=1,["minimum"]=0.01,["step"]=0.01,},{["description"]="== Fullscreen pixels == (0=Soft, 1=Sharp)",["id"]="sharp_mode",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Pixel edge sharpness",["id"]="sharpening_amount",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Scale factor",["id"]="video_scale",["initial"]=5,["maximum"]=15,["minimum"]=2,["step"]=1,},},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["size_uniforms"]={{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="unique",["name"]="blending_mode",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="adjacent_texel_alpha_blending",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
\
struct LIBRA_UBO_VERTEX\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_VERTEX LIBRA_UBO_VERTEX_INSTANCE;\
\
struct LIBRA_PUSH_VERTEX\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
    float blending_mode;\
    float adjacent_texel_alpha_blending;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_4;\
varying vec2 LIBRA_VARYING_5;\
varying vec2 LIBRA_VARYING_6;\
varying vec2 LIBRA_VARYING_7;\
vec2 texel;\
\
void main()\
{\
    gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
    LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;\
    texel = LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
    LIBRA_VARYING_3 = LIBRA_VARYING_0 + vec2(0.0, texel.y);\
    LIBRA_VARYING_2 = LIBRA_VARYING_0 + vec2(0.0, -texel.y);\
    LIBRA_VARYING_4 = LIBRA_VARYING_0 + vec2(texel.x, 0.0);\
    LIBRA_VARYING_5 = LIBRA_VARYING_0 + vec2(-texel.x, 0.0);\
    LIBRA_VARYING_6 = vec2(0.0);\
    LIBRA_VARYING_7 = texel * (LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.xy - vec2(2.0));\
}\
\
",["wrap_mode"]="clamp_to_border",},{["alias"]="PASS2",["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
\
const float _17[5] = float[](0.0, 1.0, 2.0, 3.0, 4.0);\
const float _24[5] = float[](0.134658336639404296875, 0.1305153369903564453125, 0.118835575878620147705078125, 0.10164546966552734375, 0.08167444169521331787109375);\
\
struct LIBRA_UBO_FRAGMENT\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_FRAGMENT LIBRA_UBO_FRAGMENT_INSTANCE;\
\
struct LIBRA_PUSH_FRAGMENT\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_1;\
\
void main()\
{\
    vec4 out_color = texture2D(LIBRA_TEXTURE_Source, clamp(LIBRA_VARYING_0, LIBRA_VARYING_2, LIBRA_VARYING_3)) * _24[0];\
    for (int i = 1; i < 5; i++)\
    {\
        out_color.w += (texture2D(LIBRA_TEXTURE_Source, clamp(LIBRA_VARYING_0 + vec2(_17[i] * LIBRA_VARYING_1.x, 0.0), LIBRA_VARYING_2, LIBRA_VARYING_3)).w * _24[i]);\
        out_color.w += (texture2D(LIBRA_TEXTURE_Source, clamp(LIBRA_VARYING_0 - vec2(_17[i] * LIBRA_VARYING_1.x, 0.0), LIBRA_VARYING_2, LIBRA_VARYING_3)).w * _24[i]);\
    }\
    gl_FragData[0] = out_color;\
}\
\
",["frame_count_mod"]=0,["id"]="2",["mipmap_input"]=false,["parameters"]={},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["size_uniforms"]={{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
\
struct LIBRA_UBO_VERTEX\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_VERTEX LIBRA_UBO_VERTEX_INSTANCE;\
\
struct LIBRA_PUSH_VERTEX\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
varying vec2 LIBRA_VARYING_1;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
\
void main()\
{\
    gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
    LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;\
    LIBRA_VARYING_1 = LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
    LIBRA_VARYING_2 = vec2(0.0);\
    LIBRA_VARYING_3 = LIBRA_VARYING_1 * (LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.xy - vec2(1.0));\
}\
\
",["wrap_mode"]="clamp_to_border",},{["alias"]="PASS3",["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
\
const float _17[5] = float[](0.0, 1.0, 2.0, 3.0, 4.0);\
const float _24[5] = float[](0.134658336639404296875, 0.1305153369903564453125, 0.118835575878620147705078125, 0.10164546966552734375, 0.08167444169521331787109375);\
\
struct LIBRA_UBO_FRAGMENT\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_FRAGMENT LIBRA_UBO_FRAGMENT_INSTANCE;\
\
struct LIBRA_PUSH_FRAGMENT\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_1;\
\
void main()\
{\
    vec4 out_color = texture2D(LIBRA_TEXTURE_Source, clamp(LIBRA_VARYING_0, LIBRA_VARYING_2, LIBRA_VARYING_3)) * _24[0];\
    for (int i = 1; i < 5; i++)\
    {\
        out_color.w += (texture2D(LIBRA_TEXTURE_Source, clamp(LIBRA_VARYING_0 + vec2(0.0, _17[i] * LIBRA_VARYING_1.y), LIBRA_VARYING_2, LIBRA_VARYING_3)).w * _24[i]);\
        out_color.w += (texture2D(LIBRA_TEXTURE_Source, clamp(LIBRA_VARYING_0 - vec2(0.0, _17[i] * LIBRA_VARYING_1.y), LIBRA_VARYING_2, LIBRA_VARYING_3)).w * _24[i]);\
    }\
    gl_FragData[0] = out_color;\
}\
\
",["frame_count_mod"]=0,["id"]="3",["mipmap_input"]=false,["parameters"]={},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["size_uniforms"]={{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
\
struct LIBRA_UBO_VERTEX\
{\
    mat4 MVP;\
};\
\
uniform LIBRA_UBO_VERTEX LIBRA_UBO_VERTEX_INSTANCE;\
\
struct LIBRA_PUSH_VERTEX\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
varying vec2 LIBRA_VARYING_1;\
varying vec2 LIBRA_VARYING_2;\
varying vec2 LIBRA_VARYING_3;\
\
void main()\
{\
    gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
    LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;\
    LIBRA_VARYING_1 = LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
    LIBRA_VARYING_2 = vec2(0.0);\
    LIBRA_VARYING_3 = LIBRA_VARYING_1 * (LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.xy - vec2(1.0));\
}\
\
",["wrap_mode"]="clamp_to_border",},{["alias"]="PASS4",["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
\
struct LIBRA_UBO_FRAGMENT\
{\
    mat4 MVP;\
    vec3 Gyroscope;\
    vec3 Accelerometer;\
    vec3 AccelerometerRest;\
};\
\
uniform LIBRA_UBO_FRAGMENT LIBRA_UBO_FRAGMENT_INSTANCE;\
\
struct LIBRA_PUSH_FRAGMENT\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
    vec4 PassOutputSize1;\
    float contrast;\
    float screen_light;\
    float pixel_opacity;\
    float bg_smoothing;\
    float shadow_opacity;\
    float shadow_offset_x;\
    float shadow_offset_y;\
    float screen_offset_x;\
    float screen_offset_y;\
    float shadow_enable;\
    float palette;\
    float integer_mode;\
    float shadow_motion;\
    float shadow_max_offset;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_COLOR_PALETTE;\
uniform sampler2D LIBRA_TEXTURE_PassOutput1;\
uniform sampler2D LIBRA_TEXTURE_BACKGROUND;\
uniform sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_1;\
\
vec4 get_bg_color()\
{\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 0.5)\
    {\
        return texture2D(LIBRA_TEXTURE_COLOR_PALETTE, vec2(0.25, 0.5));\
    }\
    else\
    {\
        if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 1.5)\
        {\
            return vec4(0.65100002288818359375, 0.675000011920928955078125, 0.51800000667572021484375, 1.0);\
        }\
        else\
        {\
            if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 2.5)\
            {\
                return vec4(0.736999988555908203125, 0.736999988555908203125, 0.736999988555908203125, 1.0);\
            }\
            else\
            {\
                if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 3.5)\
                {\
                    return vec4(1.0);\
                }\
                else\
                {\
                    if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 4.5)\
                    {\
                        return vec4(0.62699997425079345703125, 0.666999995708465576171875, 0.0240000002086162567138671875, 1.0);\
                    }\
                    else\
                    {\
                        if (LIBRA_PUSH_FRAGMENT_INSTANCE.palette < 5.5)\
                        {\
                            return vec4(0.02700000070035457611083984375, 0.72899997234344482421875, 0.3689999878406524658203125, 1.0);\
                        }\
                        else\
                        {\
                            return vec4(0.02700000070035457611083984375, 0.72899997234344482421875, 0.607999980449676513671875, 1.0);\
                        }\
                    }\
                }\
            }\
        }\
    }\
}\
\
void main()\
{\
    vec2 tex = floor(LIBRA_PUSH_FRAGMENT_INSTANCE.PassOutputSize1.xy * LIBRA_VARYING_0);\
    tex = (tex + vec2(0.5)) * LIBRA_PUSH_FRAGMENT_INSTANCE.PassOutputSize1.zw;\
    vec4 bg_color_cached = get_bg_color();\
    vec2 shadow_sample = LIBRA_VARYING_0 - (LIBRA_VARYING_3 + vec2(LIBRA_PUSH_FRAGMENT_INSTANCE.screen_offset_x * LIBRA_VARYING_1.x, LIBRA_PUSH_FRAGMENT_INSTANCE.screen_offset_y * LIBRA_VARYING_1.y));\
    shadow_sample = clamp(shadow_sample, vec2(0.0), vec2(1.0) - LIBRA_VARYING_1);\
    vec4 foreground = texture2D(LIBRA_TEXTURE_PassOutput1, tex - vec2(LIBRA_PUSH_FRAGMENT_INSTANCE.screen_offset_x * LIBRA_VARYING_1.x, LIBRA_PUSH_FRAGMENT_INSTANCE.screen_offset_y * LIBRA_VARYING_1.y));\
    vec4 background = texture2D(LIBRA_TEXTURE_BACKGROUND, LIBRA_VARYING_0);\
    vec4 shadows = texture2D(LIBRA_TEXTURE_Source, shadow_sample);\
    foreground *= bg_color_cached;\
    float bg_test = 0.0;\
    if (foreground.w > 0.0)\
    {\
        bg_test = 1.0;\
    }\
    background -= (((background - vec4(0.5)) * LIBRA_PUSH_FRAGMENT_INSTANCE.bg_smoothing) * bg_test);\
    float _201 = background.x;\
    float _207 = background.y;\
    float _214 = background.z;\
    vec3 _221 = clamp(vec3(bg_color_cached.x + mix(-1.0, 1.0, _201), bg_color_cached.y + mix(-1.0, 1.0, _207), bg_color_cached.z + mix(-1.0, 1.0, _214)), vec3(0.0), vec3(1.0));\
    background.x = _221.x;\
    background.y = _221.y;\
    background.z = _221.z;\
    vec4 out_color = ((shadows * shadows.w) * ((LIBRA_PUSH_FRAGMENT_INSTANCE.contrast * LIBRA_PUSH_FRAGMENT_INSTANCE.shadow_opacity) * LIBRA_PUSH_FRAGMENT_INSTANCE.shadow_enable)) + (background * (1.0 - (shadows.w * ((LIBRA_PUSH_FRAGMENT_INSTANCE.contrast * LIBRA_PUSH_FRAGMENT_INSTANCE.shadow_opacity) * LIBRA_PUSH_FRAGMENT_INSTANCE.shadow_enable))));\
    out_color = ((foreground * foreground.w) * LIBRA_PUSH_FRAGMENT_INSTANCE.contrast) + (out_color * (LIBRA_PUSH_FRAGMENT_INSTANCE.screen_light - ((foreground.w * LIBRA_PUSH_FRAGMENT_INSTANCE.contrast) * LIBRA_PUSH_FRAGMENT_INSTANCE.pixel_opacity)));\
    gl_FragData[0] = out_color;\
}\
\
",["frame_count_mod"]=0,["id"]="4",["mipmap_input"]=false,["parameters"]={{["description"]="=== GAME BOY DOT MATRIX SHADER v1.2 ===",["id"]="GAMEBOY_SHADER",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== LCD effects ==",["id"]="LCD_EFFECTS",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Turn OFF Integer Scale in Settings > Video > Scaling",["id"]="NOTE1",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  GBC: Turn OFF Core > Color Correction & Interframe Blending",["id"]="NOTE2",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  GBA: Turn ON Core > Color Correction & Interframe Blending",["id"]="NOTE3",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]=" *  Soft / circular pixels = less grid distortion",["id"]="NOTE5",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Screen position ==",["id"]="SCREEN_POSITIONING",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Blend amount",["id"]="adjacent_texel_alpha_blending",["initial"]=0.1755,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="         ↳ Auto soften (reduce distortion)",["id"]="auto_soften",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Base pixel transparency",["id"]="baseline_alpha",["initial"]=0.1,["maximum"]=1,["minimum"]=0,["step"]=0.01,},{["description"]="     ↳ Background texture smoothing",["id"]="bg_smoothing",["initial"]=0.75,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="== Pixel blending mode == (0=Blend gaps, 1=Blend all)",["id"]="blending_mode",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Pixel transparency detection == (0=Simple, 1=Perceptual)",["id"]="brightness_mode",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="== Color mode == (0=Grayscale, 1=Color)",["id"]="color_toggle",["initial"]=0,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Contrast",["id"]="contrast",["initial"]=0.95,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Grey balance",["id"]="grey_balance",["initial"]=3,["maximum"]=4,["minimum"]=0,["step"]=0.1,},{["description"]="== Display mode == (0=Full, 1=Pixel Perfect, 2=Scale factor)",["id"]="integer_mode",["initial"]=0,["maximum"]=2,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Palette (0=IMG, 1/2=Pocket, 3=B&W, 4=DMG, 5/6=Light)",["id"]="palette",["initial"]=0,["maximum"]=6,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Pixel opacity",["id"]="pixel_opacity",["initial"]=1,["maximum"]=1,["minimum"]=0.01,["step"]=0.01,},{["description"]="     ↳ Pixel shape [Sharp mode] (Circle/Rectangle)",["id"]="pixel_shape",["initial"]=1,["maximum"]=1.3,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Pixel size",["id"]="pixel_size",["initial"]=0.8,["maximum"]=1.1,["minimum"]=0.2,["step"]=0.05,},{["description"]="     ↳ Pixel softness",["id"]="pixel_softness",["initial"]=1,["maximum"]=5,["minimum"]=0.2,["step"]=0.05,},{["description"]="     ↳ Latency",["id"]="response_time",["initial"]=0,["maximum"]=0.777,["minimum"]=0,["step"]=0.111,},{["description"]="     ↳ Screen light",["id"]="screen_light",["initial"]=1,["maximum"]=2,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Screen offset horizontal",["id"]="screen_offset_x",["initial"]=0,["maximum"]=5,["minimum"]=-5,["step"]=1,},{["description"]="     ↳ Screen offset vertical",["id"]="screen_offset_y",["initial"]=0,["maximum"]=5,["minimum"]=-5,["step"]=1,},{["description"]="== Drop shadows == (OFF/ON)",["id"]="shadow_enable",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="         ↳ Max offset",["id"]="shadow_max_offset",["initial"]=2.5,["maximum"]=30,["minimum"]=0,["step"]=0.5,},{["description"]="     ↳ Shadow motion (OFF/ON)",["id"]="shadow_motion",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Shadow offset horizontal",["id"]="shadow_offset_x",["initial"]=1,["maximum"]=5,["minimum"]=-5,["step"]=0.5,},{["description"]="     ↳ Shadow offset vertical",["id"]="shadow_offset_y",["initial"]=1,["maximum"]=5,["minimum"]=-5,["step"]=0.5,},{["description"]="     ↳ Shadow opacity",["id"]="shadow_opacity",["initial"]=0.55,["maximum"]=1,["minimum"]=0.01,["step"]=0.01,},{["description"]="== Fullscreen pixels == (0=Soft, 1=Sharp)",["id"]="sharp_mode",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},{["description"]="     ↳ Pixel edge sharpness",["id"]="sharpening_amount",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=0.05,},{["description"]="     ↳ Scale factor",["id"]="video_scale",["initial"]=5,["maximum"]=15,["minimum"]=2,["step"]=1,},},["samplers"]={{["index"]=0,["name"]="COLOR_PALETTE",["semantic"]="User",["user_name"]="COLOR_PALETTE",},{["index"]=1,["name"]="PassOutput1",["semantic"]="PassOutput",},{["index"]=1,["name"]="BACKGROUND",["semantic"]="User",["user_name"]="BACKGROUND",},{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["size_uniforms"]={{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=1,["kind"]="texture",["name"]="PassOutputSize1",["semantic"]="PassOutput",},{["index"]=0,["kind"]="unique",["name"]="contrast",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="screen_light",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="pixel_opacity",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="bg_smoothing",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="shadow_opacity",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="shadow_offset_x",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="shadow_offset_y",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="screen_offset_x",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="screen_offset_y",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="shadow_enable",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="palette",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="integer_mode",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="shadow_motion",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="shadow_max_offset",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},{["index"]=0,["kind"]="unique",["name"]="Gyroscope",["semantic"]="Gyroscope",},{["index"]=0,["kind"]="unique",["name"]="Accelerometer",["semantic"]="Accelerometer",},{["index"]=0,["kind"]="unique",["name"]="AccelerometerRest",["semantic"]="AccelerometerRest",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
\
struct LIBRA_UBO_VERTEX\
{\
    mat4 MVP;\
    vec3 Gyroscope;\
    vec3 Accelerometer;\
    vec3 AccelerometerRest;\
};\
\
uniform LIBRA_UBO_VERTEX LIBRA_UBO_VERTEX_INSTANCE;\
\
struct LIBRA_PUSH_VERTEX\
{\
    vec4 OutputSize;\
    vec4 OriginalSize;\
    vec4 SourceSize;\
    vec4 PassOutputSize1;\
    float contrast;\
    float screen_light;\
    float pixel_opacity;\
    float bg_smoothing;\
    float shadow_opacity;\
    float shadow_offset_x;\
    float shadow_offset_y;\
    float screen_offset_x;\
    float screen_offset_y;\
    float shadow_enable;\
    float palette;\
    float integer_mode;\
    float shadow_motion;\
    float shadow_max_offset;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
varying vec2 LIBRA_VARYING_3;\
varying vec2 LIBRA_VARYING_1;\
float resolution_scale;\
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
    LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;\
    float scale_x = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.x / 640.0;\
    float scale_y = LIBRA_PUSH_VERTEX_INSTANCE.OutputSize.y / 480.0;\
    resolution_scale = sqrt(scale_x * scale_y);\
    vec2 gravity = vec2(0.0);\
    if (LIBRA_PUSH_VERTEX_INSTANCE.shadow_motion > 0.5)\
    {\
        vec3 accel = LIBRA_UBO_VERTEX_INSTANCE.Accelerometer;\
        bool has_sensors = length(accel) > 0.00999999977648258209228515625;\
        if (has_sensors)\
        {\
            vec3 param = accel;\
            gravity = getOrientedTilt(param);\
        }\
    }\
    if (LIBRA_PUSH_VERTEX_INSTANCE.shadow_motion > 0.5)\
    {\
        vec2 base = vec2(LIBRA_PUSH_VERTEX_INSTANCE.shadow_offset_x, LIBRA_PUSH_VERTEX_INSTANCE.shadow_offset_y);\
        LIBRA_VARYING_3 = ((base + (gravity * LIBRA_PUSH_VERTEX_INSTANCE.shadow_max_offset)) * resolution_scale) * LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
    }\
    else\
    {\
        LIBRA_VARYING_3 = (vec2(LIBRA_PUSH_VERTEX_INSTANCE.shadow_offset_x, LIBRA_PUSH_VERTEX_INSTANCE.shadow_offset_y) * resolution_scale) * LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
    }\
    LIBRA_VARYING_1 = LIBRA_PUSH_VERTEX_INSTANCE.SourceSize.zw;\
}\
\
",["wrap_mode"]="clamp_to_border",},},["textures"]={{["filter_mode"]="nearest",["mipmap"]=false,["name"]="COLOR_PALETTE",["path"]="<home>/Library/Application Support/LOVE/pokemon-love2d/shaders/handheld/shaders/gameboy/resources/palette.png",["wrap_mode"]="clamp_to_border",},{["filter_mode"]="linear",["mipmap"]=false,["name"]="BACKGROUND",["path"]="<home>/Library/Application Support/LOVE/pokemon-love2d/shaders/handheld/shaders/gameboy/resources/background.png",["wrap_mode"]="clamp_to_border",},},}
