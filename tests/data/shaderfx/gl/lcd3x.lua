return {["parameter_overrides"]={},["pass_count"]=1,["passes"]={{["filter"]="nearest",["float_framebuffer"]=false,["fragment"]="#version 120\
#extension GL_EXT_gpu_shader4 : require\
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
    uint FrameCount;\
    float brighten_scanlines;\
    float brighten_lcd;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
vec2 omega;\
\
void main()\
{\
    omega = vec2(6.283185482025146484375) * LIBRA_PUSH_FRAGMENT_INSTANCE.OriginalSize.xy;\
    vec3 res = texture2D(LIBRA_TEXTURE_Source, LIBRA_VARYING_0).xyz;\
    vec2 angle = LIBRA_VARYING_0 * omega;\
    float yfactor = (LIBRA_PUSH_FRAGMENT_INSTANCE.brighten_scanlines + sin(angle.y)) / (LIBRA_PUSH_FRAGMENT_INSTANCE.brighten_scanlines + 1.0);\
    vec3 xfactors = (vec3(LIBRA_PUSH_FRAGMENT_INSTANCE.brighten_lcd) + sin(vec3(angle.x) + vec3(1.57079637050628662109375, -0.52359879016876220703125, -2.617993831634521484375))) / vec3(LIBRA_PUSH_FRAGMENT_INSTANCE.brighten_lcd + 1.0);\
    vec3 color = (xfactors * yfactor) * res;\
    gl_FragData[0] = vec4(color.x, color.y, color.z, 1.0);\
}\
\
",["frame_count_mod"]=0,["id"]="0",["mipmap_input"]=false,["parameters"]={{["description"]="Brighten LCD",["id"]="brighten_lcd",["initial"]=4,["maximum"]=12,["minimum"]=1,["step"]=0.1,},{["description"]="Brighten Scanlines",["id"]="brighten_scanlines",["initial"]=16,["maximum"]=32,["minimum"]=1,["step"]=0.5,},},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["size_uniforms"]={{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="unique",["name"]="FrameCount",["semantic"]="FrameCount",},{["index"]=0,["kind"]="unique",["name"]="brighten_scanlines",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="brighten_lcd",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
#extension GL_EXT_gpu_shader4 : require\
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
    uint FrameCount;\
    float brighten_scanlines;\
    float brighten_lcd;\
};\
\
uniform LIBRA_PUSH_VERTEX LIBRA_PUSH_VERTEX_INSTANCE;\
\
attribute vec4 Position;\
varying vec2 LIBRA_VARYING_0;\
attribute vec2 TexCoord;\
vec2 omega;\
\
void main()\
{\
    omega = vec2(6.283185482025146484375) * LIBRA_PUSH_VERTEX_INSTANCE.OriginalSize.xy;\
    gl_Position = LIBRA_UBO_VERTEX_INSTANCE.MVP * Position;\
    LIBRA_VARYING_0 = TexCoord;\
}\
\
",["wrap_mode"]="clamp_to_border",},},["textures"]={},}
