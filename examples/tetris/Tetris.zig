const std = @import("std");
const fintui = @import("fintui");

const styles = @import("styles.zig");

const Allocator = std.mem.Allocator;

const Tetris = @This();
pub const Piece = @import("Tetris/Piece.zig");
const PieceGenerator = @import("Tetris/PieceGenerator.zig");

const main_style: fintui.Screen.Cell.Style = .{ .bg = styles.base };

piece_gen: PieceGenerator,
board: []Cell,
trails: []u8,
current_piece: Piece,
next_piece: Piece,
game_state: GameState,

const GameState = union(enum(u8)) {
    dropping: u32,
    row_clear: struct {
        rows_to_clear: u20, // packed [20]bool of which rows are clear
        frames_until_clear: u32,
    },
    lock_delay: u32,
    place_piece,
    over,
    exit,

    pub fn tetris(s: *GameState) *Tetris {
        return @alignCast(@fieldParentPtr("game_state", s));
    }

    pub fn stateDropping(s: *GameState) void {
        const t = s.tetris();

        s.dropping -= 1;
        if (s.dropping == 0) {
            s.* = .{
                .lock_delay = 30,
            };

            t.current_piece.y += 1;
        }
    }

    pub fn stateRowClear(s: *GameState) void {
        const t = s.tetris();

        s.row_clear.frames_until_clear -= 1;
        if (s.row_clear.frames_until_clear == 0) {
            t.clearRows(s.row_clear.rows_to_clear);

            s.* = .{ .dropping = 60 };
        }
    }

    pub fn statePlacePiece(s: *GameState) void {
        const t = s.tetris();
        s.* = .{ .dropping = 60 };

        if (t.pieceShouldLand(t.current_piece)) {
            t.placePiece(t.current_piece);
            t.nextPiece();

            const rows_to_clear = t.checkLines();
            if (rows_to_clear > 0) {
                s.* = .{ .row_clear = .{
                    .rows_to_clear = rows_to_clear,
                    .frames_until_clear = row_clear_frames,
                } };
            }
        }
    }

    pub fn stateLockDelay(s: *GameState) void {
        s.lock_delay -= 1;
        if (s.lock_delay == 0) {
            s.* = .place_piece;
        }
    }
};

pub const row_clear_frames = 24;

pub const Cell = enum(u8) {
    empty,
    light_blue,
    yellow,
    purple,
    green,
    red,
    dark_blue,
    orange,

    pub fn toStyle(s: Cell) fintui.Screen.Cell.Style {
        return .{
            .bg = switch (s) {
                .empty => styles.base,
                .light_blue => styles.cyan,
                .yellow => styles.yellow,
                .purple => styles.magenta,
                .green => styles.green,
                .red => styles.red,
                .dark_blue => styles.blue,
                .orange => styles.orange,
            },
        };
    }
};

fn outOfBounds(x: i32, y: i32) bool {
    return x < 0 or x >= 10 or y < 0 or y >= 20;
}

pub fn init(gpa: Allocator, rand: std.Random) Allocator.Error!Tetris {
    const board = try gpa.alloc(Cell, 10 * 20);
    const effects = try gpa.alloc(u8, 10 * 20);

    var tetris: Tetris = .{
        .piece_gen = .init(rand),
        .board = board,
        .trails = effects,
        .current_piece = undefined,
        .next_piece = undefined,
        .game_state = undefined,
    };

    tetris.reset();

    return tetris;
}

pub fn reset(s: *Tetris) void {
    @memset(s.board, .empty);
    @memset(s.trails, 0);
    s.game_state = .{ .dropping = 60 };

    s.piece_gen.reshuffleBag();
    s.current_piece = s.piece_gen.drawPiece();
    s.next_piece = s.piece_gen.drawPiece();
}

pub fn deinit(s: *Tetris, gpa: Allocator) void {
    gpa.free(s.board);
    gpa.free(s.trails);
}

pub fn nextPiece(s: *Tetris) void {
    s.current_piece = s.next_piece;
    s.next_piece = s.piece_gen.drawPiece();
    if (s.pieceIntersectsBoard(s.current_piece)) {
        s.game_state = .over;
    }
}

pub fn cellAt(s: *const Tetris, x: u8, y: u8) Cell {
    return s.board[y * 10 + x];
}

pub fn render(s: *const Tetris, tui: *fintui.Tui) fintui.Tui.DrawError!void {
    const board_x: i16 = @intCast(tui.screen.width / 2 - 10);
    const board_y: i16 = @intCast(tui.screen.height / 2 - 10);

    try tui.drawString(
        @intCast(board_x - 2),
        @intCast(board_y - 1),
        \\┌──────────────────────┐
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\│                      │
        \\└──────────────────────┘
    ,
        main_style,
    );

    try tui.drawString(
        @intCast(board_x + 23),
        @intCast(board_y - 1),
        \\┌──────────┐
        \\│          │
        \\│          │
        \\│          │
        \\│          │
        \\└──────────┘
        \\ Next piece
    ,
        main_style,
    );

    for (0..20) |j| {
        for (0..10) |i| {
            const x: i16 = @intCast(i * 2);
            const y: i16 = @intCast(j);

            var cell: fintui.Screen.Cell = .{ .style = main_style };

            const trail = &s.trails[j * 10 + i];
            const board_cell = s.board[j * 10 + i];

            if (trail.* > 0) {
                const bg_coeffecient = @as(f64, @floatFromInt(trail.*)) / 80;
                const fg_coeffecient = @as(f64, @floatFromInt(trail.* - 1)) / 80;

                cell.style.bg = styles.interpolate(styles.base.truecolor, .{ 255, 255, 255 }, bg_coeffecient);
                cell.style.fg = styles.interpolate(styles.base.truecolor, .{ 255, 255, 255 }, fg_coeffecient);

                cell.grapheme = '▀';
                if (trail.* > 0) {
                    trail.* -= 2;
                }
            }
            if (board_cell != .empty) {
                cell.style = board_cell.toStyle();
                cell.style.fg = .rgb(255, 255, 255);
                cell.grapheme = '╶';
            }
            if (s.game_state == .row_clear and (s.game_state.row_clear.rows_to_clear >> @intCast(j)) & 1 == 1) {
                const frames_until_row_clear = s.game_state.row_clear.frames_until_clear;
                const t = @as(f64, @floatFromInt(frames_until_row_clear)) / row_clear_frames;

                cell.style.bg = styles.interpolate(styles.base.truecolor, .{ 255, 255, 255 }, t);

                cell.grapheme = ' ';
            }

            try tui.drawCell(@intCast(board_x + x), @intCast(board_y + y), cell);
            if (board_cell != .empty) cell.grapheme = '╴';
            try tui.drawCell(@intCast(board_x + x + 1), @intCast(board_y + y), cell);
        }
    }

    const predicted_landing = s.predictPieceLanding(s.current_piece);
    try renderTetromino(tui, predicted_landing, board_x, board_y, .{
        .bg = .rgb(54, 58, 79),
    });

    try renderTetromino(tui, s.current_piece, board_x, board_y, null);
    if (s.next_piece.kind >= 2) {
        try renderTetromino(tui, s.next_piece, board_x + 20, board_y + 1, null);
    } else {
        try renderTetromino(tui, s.next_piece, board_x + 19, board_y, null);
    }
}

pub fn renderTetromino(tui: *fintui.Tui, tetromino: Tetris.Piece, offset_x: i16, offset_y: i16, style: ?fintui.Screen.Cell.Style) fintui.Tui.DrawError!void {
    const piece_data = tetromino.getData();
    const piece_color = Tetris.Piece.piece_colors[tetromino.kind];

    const cell: fintui.Screen.Cell = .{
        .style = style orelse piece_color.toStyle(),
    };

    for (0..4) |j| {
        for (0..4) |i| {
            if ((piece_data >> (@as(u4, @intCast(j)) * 4 + @as(u4, @intCast(i)))) & 1 == 1) {
                const x: i16 = @intCast((@as(i8, @intCast(i)) + tetromino.x) * 2);
                const y: i16 = @intCast(@as(i8, @intCast(j)) + tetromino.y);

                try tui.drawCell(@intCast(offset_x + x), @intCast(offset_y + y), cell);
                try tui.drawCell(@intCast(offset_x + x + 1), @intCast(offset_y + y), cell);
            }
        }
    }
}

pub fn pieceIntersectsBoard(s: *const Tetris, piece: Piece) bool {
    const piece_data = piece.getData();

    for (0..4) |j| {
        for (0..4) |i| {
            const x: i8 = @intCast(i);
            const y: i8 = @intCast(j);
            if ((piece_data >> @as(u4, @intCast(j * 4 + i)) & 1) == 0) continue;

            const board_x: i8 = @intCast(x + piece.x);
            const board_y: i8 = @intCast(y + piece.y);

            if (outOfBounds(board_x, board_y) or
                s.cellAt(@intCast(board_x), @intCast(board_y)) != .empty)
            {
                return true;
            }
        }
    }

    return false;
}

pub fn predictPieceLanding(s: *const Tetris, piece: Piece) Piece {
    var new_piece = piece;

    while (true) {
        if (s.pieceShouldLand(new_piece)) {
            return new_piece;
        }
        new_piece.y += 1;
    }
}

pub fn pieceShouldLand(s: *const Tetris, piece: Piece) bool {
    const piece_data = piece.getData();
    for (0..4) |j| {
        for (0..4) |i| {
            const x: i8 = @intCast(i);
            const y: i8 = @intCast(j);

            const piece_block_here = (piece_data >> @as(u4, @intCast(j * 4 + i))) & 1 == 1;
            if (!piece_block_here) continue;

            const board_x: u8 = @intCast(x + piece.x);
            const board_y: u8 = @intCast(y + piece.y);

            const below_is_landable = board_y + 1 >= 20 or s.cellAt(board_x, board_y + 1) != .empty;
            if (below_is_landable) {
                return true;
            }
        }
    }

    return false;
}

pub fn placePiece(s: *Tetris, piece: Piece) void {
    const piece_data = piece.getData();

    for (0..4) |j| {
        for (0..4) |i| {
            const x: i8 = @intCast(i);
            const y: i8 = @intCast(j);

            const piece_block_here = (piece_data >> @as(u4, @intCast(j * 4 + i))) & 1 == 1;
            if (!piece_block_here) continue;

            const board_x: u8 = @intCast(x + piece.x);
            const board_y: u8 = @intCast(y + piece.y);

            s.board[board_y * 10 + board_x] = Tetris.Piece.piece_colors[piece.kind];
        }
    }
}

fn isLineFull(s: *const Tetris, row: u8) bool {
    for (0..10) |i| {
        if (s.board[row * 10 + i] == .empty) return false;
    }
    return true;
}

fn clearRows(s: *Tetris, row_clears: u20) void {
    for (0..20) |row| {
        if ((row_clears >> @intCast(row)) & 1 == 0) continue;
        var j = row - 1;
        while (j > 0) {
            for (0..10) |i| {
                s.board[(j + 1) * 10 + i] = s.board[j * 10 + i];
            }
            j -= 1;
        }
    }
}

pub fn checkLines(s: *Tetris) u20 {
    var row_clears: u20 = 0;

    for (0..20) |row| {
        if (!s.isLineFull(@intCast(row))) continue;

        row_clears |= @as(u20, 1) << @intCast(row);
    }

    return row_clears;
}

pub fn handlePlayingEvent(s: *Tetris, event: fintui.Tui.Event) void {
    if (event != .key) return;
    const key = event.key;

    switch (key) {
        .lower_q, .upper_q => s.game_state = .exit,
        .lower_j, .upper_j => {
            s.current_piece.x -= 1;
            if (s.pieceIntersectsBoard(s.current_piece)) {
                s.current_piece.x += 1;
            }
        },
        .lower_l, .upper_l => {
            s.current_piece.x += 1;
            if (s.pieceIntersectsBoard(s.current_piece)) {
                s.current_piece.x -= 1;
            }
        },
        .lower_k, .upper_k => {
            s.current_piece.rot +%= 1;
            if (s.pieceIntersectsBoard(s.current_piece)) {
                s.current_piece.rot -%= 1;
            }
        },
        .lower_i, .upper_i => {
            if (s.game_state == .dropping) {
                s.game_state.dropping = 1;
            }
        },
        .space => {
            const piece_place = s.predictPieceLanding(s.current_piece);

            const prev_y: u8 = @intCast(s.current_piece.y);
            const new_y: u8 = @intCast(piece_place.y);

            s.current_piece = piece_place;
            s.game_state = .place_piece;

            const piece_range = piece_place.posRange();
            for (prev_y + piece_range.min_y..new_y + piece_range.max_y) |j| {
                for (piece_range.min_x..piece_range.max_x + 1) |i| {
                    const y: u8 = @intCast(j);

                    const x: u8 = @intCast(@as(i8, @intCast(i)) + piece_place.x);

                    // const piece_width: i32 = @intCast(piece_range.max_x - piece_range.min_x + 1);
                    // const dist_from_middle = @abs(@as(i32, @intCast(i)) * 2 - (piece_width - 1));
                    //
                    // if (dist_from_middle > 1) {
                    // if (j > prev_y + piece_range.min_y + 1) {
                    //         s.trails[j * 10 + x] = (y - prev_y - piece_range.min_y) * 2 - 2;
                    //     }
                    // } else {
                    s.trails[j * 10 + x] = (y - prev_y - piece_range.min_y) * 2;
                    // }
                }
            }
        },
        else => {},
    }
}

pub fn handleGameOverEvent(s: *Tetris, event: fintui.Tui.Event) void {
    if (event != .key) return;
    const key = event.key;
    if (key == .lower_q or key == .upper_q) s.game_state = .exit;
    if (key == .space) {
        s.reset();
    }
}
