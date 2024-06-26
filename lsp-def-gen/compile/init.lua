local Buffer = require("lsp-def-gen.compile.util.Buffer")

local INDENT_CHAR = "\t"

---@class compile
local compile = {}

---@param sep? string
---@return Buffer
function compile:buffer(sep)
	return Buffer(sep)
end

---@param buffer table
---@return Buffer
function compile:bufferOf(buffer)
	setmetatable(buffer, Buffer)
	return buffer
end

---@param str string
---@return fun(): string
local function lines(str)
	return string.gmatch(str, "[^\n]+")
end

---@param str string
---@param indent? integer
---@return Buffer
function compile:docComment(str, indent)
	indent = indent or 0
	local buffer = Buffer("\n")
	for line in lines(str) do
		buffer:append(INDENT_CHAR:rep(indent) .. "---" .. line)
	end

	return buffer
end

return compile
