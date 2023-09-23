#version 330 core
layout (location = 0) in vec3 pos;

//uniform mat4 _P;
uniform vec3 _Offset;
uniform mat4 _P;

// vec4 local2clip(vec4 localPos)
// {
// 	return _P * localPos; // _V * _M * 
// }

void main()
{
    //gl_Position = local2clip(vec4(pos, 1.0)); // vec4(pos.x, pos.y, pos.z, 1.0);
    //pos += _Offset;
    vec3 p = pos + _Offset;
    gl_Position = _P * vec4(p.x, p.y, p.z, 1.0);
}