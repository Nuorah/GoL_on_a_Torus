#version 330 core
in vec2 FragUV;
in vec3 FragNormal;
in vec3 FragPos;

out vec4 FragColor;

uniform sampler2D uGrid;

void main() {
    float cell = texture(uGrid, FragUV).r;
    
    // alive = white, dead = dark gray
    vec3 color = mix(vec3(0.1), vec3(1.0), cell);
    
    // basic lighting so we see the shape
    vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
    vec3 normal = normalize(FragNormal);
    float diff = max(dot(normal, lightDir), 0.3);
    
    FragColor = vec4(color * diff, 1.0);
}
