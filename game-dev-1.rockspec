rockspec_format = "3.0"
package = "game"
version = "dev-1"

source = {
    url = ".",
}

description = {
    summary = "Tecs starter game",
    license = "UNLICENSED",
}

dependencies = {
    "lua == 5.1",
    "tl == dev-1",
    "tecs == dev-1",
    "tecs2d == dev-1",
    "luajit-tl-type == 0.0.2",
    "luasocket-tl-type == 0.0.2",
    "tecs-love2d-tl-type >= 0.1.0",
}

build = {
    type = "builtin",
    modules = {},
}
