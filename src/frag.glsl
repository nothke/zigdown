#version 330 core
out vec4 FragColor;

in vec3 out_norm;

void main()
{
    FragColor = vec4(1.0f + out_norm.x, 0.5f + out_norm.y, 1.0f + out_norm.z, 1.0f);
} 