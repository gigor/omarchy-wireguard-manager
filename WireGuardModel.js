.pragma library

var NAME_PATTERN = /^[A-Za-z0-9_=+.-]{1,15}$/
var CONFIG_DIR = "/etc/wireguard"

// The only tunnels the widget shows and toggles. A fixed list instead of a
// directory scan, so /etc/wireguard can stay root-only (no ACL for the user).
var CONNECTIONS = ["wg-servers"]

function isValidName(name) {
    return NAME_PATTERN.test(String(name || ""))
}

function connectionNames() {
    var names = []
    for (var i = 0; i < CONNECTIONS.length; i++) {
        if (isValidName(CONNECTIONS[i]) && names.indexOf(CONNECTIONS[i]) === -1) names.push(CONNECTIONS[i])
    }
    names.sort()
    return names
}

function isAllowedName(name) {
    return isValidName(name) && CONNECTIONS.indexOf(name) !== -1
}

function parseInterfaces(raw) {
    var active = {}
    var tokens = String(raw || "").trim().split(/\s+/)
    if (tokens.length === 1 && tokens[0] === "") return active
    for (var i = 0; i < tokens.length; i++) {
        if (isValidName(tokens[i])) active[tokens[i]] = true
    }
    return active
}

function configPath(name) {
    if (!isValidName(name)) return ""
    return CONFIG_DIR + "/" + name + ".conf"
}

function statusCommand() {
    return ["/usr/bin/wg", "show", "interfaces"]
}

function toggleCommand(name, action) {
    if ((action !== "up" && action !== "down") || !isAllowedName(name)) return []
    var path = configPath(name)
    if (!path) return []
    return ["/usr/bin/pkexec", "/usr/bin/wg-quick", action, path]
}

function expectedState(action) {
    return action === "up" ? "active" : "inactive"
}
