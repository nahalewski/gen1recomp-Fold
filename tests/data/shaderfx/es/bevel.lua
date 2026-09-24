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
    float BEVEL_LEVEL;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform highp sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
\
vec3 bevel(vec2 pos, vec3 color)\
{\
    float r = sqrt(dot(pos, vec2(1.0)));\
    vec3 delta = mix(vec3(LIBRA_PUSH_FRAGMENT_INSTANCE.BEVEL_LEVEL), vec3(1.0 - LIBRA_PUSH_FRAGMENT_INSTANCE.BEVEL_LEVEL), color);\
    vec3 weight = delta * (1.0 - r);\
    return color + weight;\
}\
\
void main()\
{\
    vec2 position = fract(LIBRA_VARYING_0 * LIBRA_PUSH_FRAGMENT_INSTANCE.SourceSize.xy);\
    vec3 color = pow(texture2D(LIBRA_TEXTURE_Source, LIBRA_VARYING_0).xyz, vec3(2.400000095367431640625));\
    vec2 param = position;\
    vec3 param_1 = color;\
    color = clamp(bevel(param, param_1), vec3(0.0), vec3(1.0));\
    gl_FragData[0] = vec4(pow(color, vec3(0.4545454680919647216796875)), 1.0);\
}\
\
",["frame_count_mod"]=0,["id"]="0",["mipmap_input"]=false,["parameters"]={{["description"]="Bevel Level",["id"]="BEVEL_LEVEL",["initial"]=0.2,["maximum"]=0.5,["minimum"]=0,["step"]=0.01,},},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["size_uniforms"]={{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="unique",["name"]="FrameCount",["semantic"]="FrameCount",},{["index"]=0,["kind"]="unique",["name"]="BEVEL_LEVEL",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 100\
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
    float BEVEL_LEVEL;\
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
    LIBRA_VARYING_0 = TexCoord;\
}\
\
",["wrap_mode"]="clamp_to_border",},},["textures"]={},}
