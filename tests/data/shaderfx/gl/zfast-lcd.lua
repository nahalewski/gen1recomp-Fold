return {["parameter_overrides"]={},["pass_count"]=1,["passes"]={{["filter"]="linear",["float_framebuffer"]=false,["fragment"]="#version 120\
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
    float BORDERMULT;\
    float GBAGAMMA;\
};\
\
uniform LIBRA_PUSH_FRAGMENT LIBRA_PUSH_FRAGMENT_INSTANCE;\
\
uniform sampler2D LIBRA_TEXTURE_Source;\
\
varying vec2 LIBRA_VARYING_0;\
\
void main()\
{\
    vec2 texcoordInPixels = LIBRA_VARYING_0 * LIBRA_PUSH_FRAGMENT_INSTANCE.SourceSize.xy;\
    vec2 centerCoord = floor(texcoordInPixels) + vec2(0.5);\
    vec2 distFromCenter = abs(centerCoord - texcoordInPixels);\
    float Y = max(distFromCenter.x, distFromCenter.y);\
    Y *= Y;\
    float YY = Y * Y;\
    float YYY = YY * Y;\
    float LineWeight = YY - (2.7000000476837158203125 * YYY);\
    LineWeight = 1.0 - (LIBRA_PUSH_FRAGMENT_INSTANCE.BORDERMULT * LineWeight);\
    vec3 colour = texture2D(LIBRA_TEXTURE_Source, LIBRA_PUSH_FRAGMENT_INSTANCE.SourceSize.zw * centerCoord).xyz * LineWeight;\
    if (LIBRA_PUSH_FRAGMENT_INSTANCE.GBAGAMMA > 0.5)\
    {\
        colour *= (vec3(0.60000002384185791015625) + (colour * 0.4000000059604644775390625));\
    }\
    gl_FragData[0] = vec4(colour, 1.0);\
}\
\
",["frame_count_mod"]=0,["id"]="0",["mipmap_input"]=false,["parameters"]={{["description"]="Border Multiplier",["id"]="BORDERMULT",["initial"]=14,["maximum"]=40,["minimum"]=-40,["step"]=1,},{["description"]="GBA Gamma Hack",["id"]="GBAGAMMA",["initial"]=1,["maximum"]=1,["minimum"]=0,["step"]=1,},},["samplers"]={{["index"]=0,["name"]="Source",["semantic"]="Source",},},["scale_x"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["scale_y"]={["factor"]=1,["factor_kind"]="float",["scale_type"]="viewport",},["size_uniforms"]={{["index"]=0,["kind"]="texture",["name"]="SourceSize",["semantic"]="Source",},{["index"]=0,["kind"]="texture",["name"]="OriginalSize",["semantic"]="Original",},{["index"]=0,["kind"]="unique",["name"]="OutputSize",["semantic"]="Output",},{["index"]=0,["kind"]="unique",["name"]="FrameCount",["semantic"]="FrameCount",},{["index"]=0,["kind"]="unique",["name"]="BORDERMULT",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="GBAGAMMA",["semantic"]="FloatParameter",},{["index"]=0,["kind"]="unique",["name"]="MVP",["semantic"]="MVP",},},["srgb_framebuffer"]=false,["vertex"]="#version 120\
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
    float BORDERMULT;\
    float GBAGAMMA;\
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
