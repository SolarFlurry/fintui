const fintui = @import("fintui");
const Color = fintui.Screen.Cell.Color;

pub const red: Color = .rgb(237, 135, 150);
pub const orange: Color = .rgb(245, 169, 127);
pub const yellow: Color = .rgb(238, 212, 159);
pub const green: Color = .rgb(166, 218, 149);
pub const cyan: Color = .rgb(139, 213, 202);
pub const blue: Color = .rgb(138, 173, 244);
pub const magenta: Color = .rgb(198, 160, 246);

pub const text: Color = .rgb(202, 211, 245);
pub const base: Color = .rgb(36, 39, 58);
pub const surface0: Color = .rgb(54, 58, 79);

pub fn interpolate(a: [3]u8, b: [3]u8, t: f64) Color {
    return .rgb(
        @trunc((1 - t) * a[0] + t * b[0]),
        @trunc((1 - t) * a[1] + t * b[1]),
        @trunc((1 - t) * a[2] + t * b[2]),
    );
}
