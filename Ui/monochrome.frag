#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;
    bool preserveTone;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 pixel = texture(source, qt_TexCoord0);
    float gray = dot(ink.rgb, vec3(0.299, 0.587, 0.114));
    float tone = preserveTone && pixel.a > 0.0
        ? dot(pixel.rgb, vec3(0.299, 0.587, 0.114)) / pixel.a : 1.0;
    fragColor = vec4(vec3(gray * tone) * pixel.a, ink.a * pixel.a) * qt_Opacity;
}
