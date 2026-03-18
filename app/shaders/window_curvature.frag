#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform ubuf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float screenCurvature;
};
layout(binding = 1) uniform sampler2D source;

vec2 distortCoordinates(vec2 coords) {
    vec2 cc = coords - vec2(0.5);
    float dist = dot(cc, cc) * screenCurvature;
    return coords + cc * (1.0 + dist) * dist;
}

void main() {
    vec2 coords = distortCoordinates(qt_TexCoord0);
    if (coords.x < 0.0 || coords.x > 1.0 || coords.y < 0.0 || coords.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0) * qt_Opacity;
        return;
    }
    fragColor = texture(source, coords) * qt_Opacity;
}
