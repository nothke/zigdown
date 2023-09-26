#version 330 core
out vec4 FragColor;

in vec2 out_uv;

uniform sampler2D _Texture;

void main()
{
    FragColor = texture(_Texture, out_uv);
} 