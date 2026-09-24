return {["parameter_overrides"]={},["pass_count"]=1,["passes"]={{["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 100\
precision highp float;\
precision highp int;\
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
    vec4 SourceSize;\
    vec4 OriginalSize;\
    vec4 OutputSize;\
    lowp int FrameCount;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform highp sampler2D LIBRA_TEXTURE_Source;\
uniform highp sampler2D LIBRA_TEXTURE_COLOR_PALETTE;\
\
varying vec2 LIBRA_VARYING_0;\
\
void main()\
{\
    vec4 out_color = texture2D(LIBRA_TEXTURE_Source, LIBRA_VARYING_0);\
    vec2 palette_coordinate = vec2(0.5, (abs(1.0 - out_color.x) * 0.75) + 0.125);\
    out_color = vec4(texture2D(LIBRA_TEXTURE_COLOR_PALETTE, palette_coordinate).xyz, ceil(abs(1.0 - out_color.x)));\
    gl_FragData[0] = out_color;\
}\
\
",["frame_count_mod"]=0,["id"]="0",["mipmap_input"]=false,["parameters"]={},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},{["index"]=0,["name"]="COLOR_PALETTE",["semantic"]="User",["user_name"]="COLOR_PALETTE",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="source",},["size_uniforms"]={{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="unique",["name"]="FrameCount",["semantic"]="FrameCount",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 100\
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
    vec4 SourceSize;\
    vec4 OriginalSize;\
    vec4 OutputSize;\
    lowp int FrameCount;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
\
void main()\
{\
    gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
    LIBRA_VARYING_0 = TexCoord * 1.00010001659393310546875;\
}\
\
",["wrap_mode"]="clamp_to_border",},},["textures"]={{["filter_mode"]="nearest",["mipmap"]=false,["name"]="COLOR_PALETTE",["path"]="<home>/Library/Application Support/LOVE/pokemon-love2d/shaders/handheld/shaders/gb-palette/resources/palette-dmg.png",["wrap_mode"]="clamp_to_border",},},}
