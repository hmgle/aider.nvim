local M = {}

--- Clean line outputs for aider
---@param line string
---@return string
function M.clean_output(line)
	local gsub_patterns = {
		{ ".*{EOF.*" },
		{ ".*EOF}.*" },
		{ "%[%d+ q" },
		{ "\27%[38;2;%d+;%d+;%d+m" },
		{ "\27%[48;2;%d+;%d+;%d+m" },
		{ "\27%[%d+;%d+;%d+;%d+;%d+m" },
		{ "\27%[%d+;%d+;%d+;%d+;%d+;%d+;%d+;%d+m" },
		{ "\27%[38;2;%d+;%d+;%d+;48;2;%d+;%d+;%d+m" },
		{ "\27%[48;2;%d+;%d+;%d+;38;2;%d+;%d+;%d+m" },
		{ "38;2;%d+;%d+;%d+;48;2;%d+;%d+;%d+m" },
		{ "48;2;%d+;%d+;%d+;38;2;%d+;%d+;%d+m" },
		{ "38;2;%d+;%d+;%d+m" },
		{ "48;2;%d+;%d+;%d+m" },
		{ "%[([%d;]+)m" },
		{ "([%d;]+)m" },
		{ "\27%[%?%d+[hl]" },
		{ "\27%[[%d;]*[A-Za-z]" },
		{ "\27%[%d*[A-Za-z]" },
		{ "\27%(%[%d*;%d*[A-Za-z]" },
		{ "^%s*%d+%s*│%s*" },
		{ "^%s*▎?│%s*" },
		{ "[\r\n]" },
		{ "[\b]" },
		{ "[\a]" },
		{ "[\t]", "  " },
		{ "[%c]" },
		{ "^%s*>%s*$" },
		{ "^%s*lua/[%w/_]+%.lua%s*$" },
		{ "%(%d+x%)" },
		{ "%s*INFO%s*$" },
	}

	for _, pattern in ipairs(gsub_patterns) do
		line = line:gsub(pattern[1], pattern[2] or "")
	end

	if line:match("^%s*$") then
		return ""
	end
	return line
end

---@return string
function M.cwd()
	return vim.fn.getcwd(-1, -1)
end

---@return string
function M.truncate_message(msg, max_length)
	if #msg > max_length then
		return msg:sub(1, max_length - 3) .. ".."
	end
	return msg
end

--- Get code comment text from a buffer
---@param bufnr
---@return nil|string[]
function M.get_comments(bufnr)
	local success, parser = pcall(vim.treesitter.get_parser, bufnr)
	if not success or not parser then
		return nil
	end
	local tree = parser:parse()[1]
	if not tree then
		print("Failed to parse buffer " .. bufnr)
		return nil
	end
	local filetype = vim.bo[bufnr].filetype
	if not filetype then
		print("No filetype detected for buffer " .. bufnr)
		return nil
	end
	local query_string = [[
(comment) @comment
]]
	local ok, query = pcall(vim.treesitter.query.parse, filetype, query_string)
	if not ok then
		print("Failed to parse query for filetype: " .. filetype)
		return nil
	end
	local comments = {}
	for _, captures, _ in query:iter_matches(tree:root(), bufnr) do
		if captures[1] then -- captures[1] corresponds to @comment
			local node = captures[1]
			local start_row, start_col, end_row, end_col = node:range()

			-- Get all lines of the comment
			local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

			-- Process each line to remove delimiter and trim
			local comment_lines = {}
			for i, line in ipairs(lines) do
				if i == 1 then
					-- Find and remove the comment delimiter only on the first line
					line = line:gsub("^%s*([%-%-/%#]+%s*)", "")
				end
				-- Trim leading and trailing whitespace
				line = line:match("^%s*(.-)%s*$")
				table.insert(comment_lines, line)
			end

			-- Join the processed lines
			local text = table.concat(comment_lines, "\n")
			table.insert(comments, text)
		end
	end
	return comments
end

---@param bufnr
---@return table<string, boolean>|nil
function M.get_comment_matches(bufnr)
	local matches = {
		["ai?"] = false,
		["ai!"] = false,
		["ai"] = false,
	}

	local comments = M.get_comments(bufnr)
	if not comments then
		return nil
	end
	for _, comment in ipairs(comments) do
		local lowered = comment:lower()

		if
			lowered:match("^%s*ai%?%s+") -- starts with "ai? "
			or lowered:match("%s+ai%?%s*$") -- ends with " ai?"
		then
			matches["ai?"] = true
		end
		if
			lowered:match("^%s*ai!%s+") -- starts with "ai! "
			or lowered:match("%s+ai!%s*$") -- ends with " ai!"
		then
			matches["ai!"] = true
		end
		if
			lowered:match("^%s*ai%s+") -- starts with "ai "
			or lowered:match("%s+ai%s*$") -- ends with " ai"
		then
			matches["ai"] = true
		end
	end
	if next(matches) ~= nil then
		return matches
	end
	return nil
end

return M
