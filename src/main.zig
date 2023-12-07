const std = @import("std");
const math = std.math;
const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL2_gfxPrimitives.h");
});

const HEIGHT = 600;
const WIDTH = 600;
const FPS = 60;
const DT_TIME: f32 = 1.0 / @as(f32, @floatFromInt(FPS));

const BACKGROUND_COLOR = 0x181818FF;
const PLAYER_COLOR = 0x523261FF;

const PLAYER_RADIUS = 0.5 * ONE_METER;

const ONE_METER = 100;
const GRAVITY = 2 * ONE_METER;

var player_x: f32 = WIDTH / 2;
var player_y: f32 = 0;
var player_velx: f32 = 6 * ONE_METER;
var player_vely: f32 = 2 * ONE_METER;
var player_dirx: f32 = 0;
var player_diry: f32 = 1;
var player_acl: f32 = 5 * ONE_METER;
var player_jumping: bool = false;

var running: bool = true;

fn addAccelerationY(amount: f32) void {
    player_acl -= amount;
}

fn playerHorizontalCollision() void {
    const new_velx = player_velx * DT_TIME * player_dirx;
    const new_x: f32 = math.clamp(player_x + new_velx, PLAYER_RADIUS, WIDTH - PLAYER_RADIUS);
    std.debug.print("x {any} dirx {any} new_x {any} velx {any} nvelx {any} ac{any}\n", .{ player_x, player_dirx, new_x, player_velx, new_velx, player_acl });
    player_x = new_x;
}

fn playerVerticalCollission() void {
    const new_vely = DT_TIME * (player_vely + player_acl);
    const new_y: f32 = math.clamp(player_y + new_vely, PLAYER_RADIUS, HEIGHT - PLAYER_RADIUS);

    if (new_y == HEIGHT - PLAYER_RADIUS) {
        player_acl = 0;
        player_vely = 0;
        player_jumping = false;
    } else {
        player_vely = new_vely;
        addAccelerationY(-GRAVITY);
    }

    std.debug.print("y {any} diry {any} new_y {any} vely {any} nvely {any} ac{any}\n", .{ player_y, player_diry, new_y, player_vely, new_vely, player_acl });
    player_y = new_y;
}

fn playerRect(x: f32, y: f32) c.SDL_Rect {
    return makeRect(x, y, PLAYER_RADIUS, 50);
}

fn makeRect(x: f32, y: f32, w: f32, h: f32) c.SDL_Rect {
    return c.SDL_Rect{
        .h = @as(i32, @intFromFloat(h)),
        .w = @as(i32, @intFromFloat(w)),
        .x = @as(i32, @intFromFloat(x)),
        .y = @as(i32, @intFromFloat(y)),
    };
}

fn setColor(renderer: *c.SDL_Renderer, color: u32) void {
    const r = @as(u8, @truncate((color >> (8 * 3)) & 0xFF));
    const g = @as(u8, @truncate((color >> (8 * 2)) & 0xFF));
    const b = @as(u8, @truncate((color >> (8 * 1)) & 0xFF));
    const a = @as(u8, @truncate((color >> (8 * 0)) & 0xFF));
    _ = c.SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

fn cleanUp(renderer: *c.SDL_Renderer, color: u32) void {
    setColor(renderer, color);
    _ = c.SDL_RenderClear(renderer);
}

fn updateScene() void {
    playerHorizontalCollision();
    playerVerticalCollission();
}

fn renderScene(renderer: *c.SDL_Renderer) void {
    _ = c.filledCircleColor(renderer, @as(i16, @intFromFloat(player_x)), @as(i16, @intFromFloat(player_y)), PLAYER_RADIUS, PLAYER_COLOR);
}

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_EVERYTHING) != 0) {
        c.SDL_Log("cannot init SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Space Zig", 0, 0, WIDTH, HEIGHT, 0) orelse {
        c.SDL_Log("cannot create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
        c.SDL_Log("cannot create renderer: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const keyboard = c.SDL_GetKeyboardState(null);

    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            if (event.type == c.SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    c.SDLK_ESCAPE => running = false,
                    else => {},
                }
            } else {} // nothing
        }

        if (keyboard[c.SDL_SCANCODE_SPACE] != 0) {
            if (!player_jumping) {
                player_jumping = true;
                addAccelerationY(30 * ONE_METER);
            }
        }

        player_dirx = 0;
        if (keyboard[c.SDL_SCANCODE_A] != 0) {
            player_dirx = -1;
        }

        if (keyboard[c.SDL_SCANCODE_D] != 0) {
            player_dirx = 1;
        }

        if (keyboard[c.SDL_SCANCODE_W] != 0) {
            player_diry = -1;
        }

        if (keyboard[c.SDL_SCANCODE_S] != 0) {
            player_diry = 1;
        }

        cleanUp(renderer, BACKGROUND_COLOR);

        updateScene();

        renderScene(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000 / FPS);
    }
}
