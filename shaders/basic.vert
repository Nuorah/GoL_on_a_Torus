#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aUV;
layout (location = 2) in vec3 aNormal;
layout (location = 3) in vec4 aTangent;
layout (location = 4) in ivec4 aBoneIds;
layout (location = 5) in vec4 aBoneWeights;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

out vec2 FragUV;
out vec3 FragNormal;
out vec3 FragPos;

void main() {
    vec4 worldPos = uModel * vec4(aPos, 1.0);
    FragPos = worldPos.xyz;
    FragUV = aUV;
    FragNormal = mat3(uModel) * aNormal;
    gl_Position = uProjection * uView * worldPos;
}
