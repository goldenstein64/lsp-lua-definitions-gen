local json = require("dkjson").use_lpeg()
local compile = require("lsp-def-gen.compile")
local compile_lib = require("lsp-def-gen.compile-lib")
local lfs = require("lfs")

local ENUM_PATH_FORMAT = "out/enum/%s.lua"

local REQUEST_PATH_FORMAT = "out/routes/%s.lua"
local REQUEST_DIR_FORMAT = "out/routes/%s"

local REQUEST_READ_FORMAT = [[
---@param params lsp.Request.%s.params
---@return lsp.Response.%s.result
return function(params) end
]]

local NOTIFICATION_PATH_FORMAT = "out/routes/%s.lua"
local NOTIFICATION_DIR_FORMAT = "out/routes/%s"

local NOTIFICATION_READ_FORMAT = [[
---@param params lsp.Notification.%s.params
---@return nil -- notifications don't expect a response
return function(params) end
]]

---@param path string
local function ensureDir(path)
	local workingPath = ""
	for folderName in path:gmatch("[^/]+") do
		if workingPath == "" then
			workingPath = folderName
		else
			workingPath = workingPath .. "/" .. folderName
		end
		local s, err = lfs.mkdir(workingPath)
		assert(s or err == "File exists", err)
	end
end

return function()
	local object do
		local data = assert(io.open("data/metaModel.json"))
		local content = data:read("a")

		---@type lspm.MetaModel
		object = assert(json.decode(content, 1, json.null))
	end

	local definitions, enums = compile:metamodel(object)
	local libDefs = compile_lib:metamodel(object)

	ensureDir("out") do
		local definitionsFile = assert(io.open("out/lsp.d.lua", "w"))
		definitionsFile:write(tostring(definitions))
		definitionsFile:close()

		local libDefsFile = assert(io.open("out/lsp-lib.d.lua", "w"))
		libDefsFile:write(tostring(libDefs))
		libDefsFile:close()
	end

	ensureDir("out/enum") do
		for name, buffer in pairs(enums) do
			local outFile = assert(io.open(ENUM_PATH_FORMAT:format(name), "w"))
			outFile:write(tostring(buffer))
			outFile:close()
		end
	end

	ensureDir("out/routes") do
		do
			for _, request in ipairs(object.requests) do
				local method = request.method
				local methodTypeName = method:gsub("%$", "_"):gsub("/", "-")
				local dir = request.messageDirection
				local content
				if dir == "clientToServer" then
					content = REQUEST_READ_FORMAT:format(methodTypeName, methodTypeName, method)
				elseif dir ~= "serverToClient" then
					error(string.format("unhandled message direction '%s'", dir))
				end

				if content then
					local moduleName = method:match("/([^/]+)$")
					local parentPath
					if moduleName then
						parentPath = assert(method:match("^(.+)/[^/]+$"), "parent path not found")
						ensureDir(REQUEST_DIR_FORMAT:format(parentPath))
					else
						moduleName = method
					end

					local requestPath = REQUEST_PATH_FORMAT:format(method)
					local requestFile = assert(io.open(requestPath, "w"))
					requestFile:write(content)
					requestFile:close()
				end
			end
		end

		do
			for _, notification in ipairs(object.notifications) do
				-- generate a file in routes
				local method = notification.method
				local methodTypeName = method:gsub("%$", "_"):gsub("/", "-")
				local dir = notification.messageDirection
				local content
				if dir == "clientToServer" or dir =="both" then
					content = NOTIFICATION_READ_FORMAT:format(methodTypeName, method)
				end

				if content then
					local moduleName = method:match("/([^/]+)$")
					if moduleName then
						local parentPath = assert(method:match("^(.+)/[^/]+$"), "parent path not found")
						ensureDir(NOTIFICATION_DIR_FORMAT:format(parentPath))
					else
						moduleName = method
					end

					local notificationFile = assert(io.open(NOTIFICATION_PATH_FORMAT:format(method), "w"))
					notificationFile:write(content)
					notificationFile:close()
				end
			end
		end
	end
end
