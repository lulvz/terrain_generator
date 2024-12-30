const std = @import("std");

pub usingnamespace @cImport({
    @cInclude("stdlib.h");
    
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});
