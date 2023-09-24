#version 330 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec3 norm;
layout (location = 3) in vec4 col;

out vec3 out_norm;

//uniform mat4 _P;
uniform vec3 _Offset;
uniform mat4 _P;
uniform mat4 _V;
uniform mat4 _M;

// vec4 local2clip(vec4 localPos)
// {
// 	return _P * localPos; // _V * _M * 
// }

// _P * _V * _M * localPos;

void main()
{
    //gl_Position = local2clip(vec4(pos, 1.0)); // vec4(pos.x, pos.y, pos.z, 1.0);
    //pos += _Offset;
    vec3 p = pos + _Offset;
    gl_Position = _P * _V * _M * vec4(p.x, p.y, p.z, 1.0);
    out_norm = norm;
}