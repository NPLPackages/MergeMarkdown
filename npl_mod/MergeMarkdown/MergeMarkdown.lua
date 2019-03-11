--[[
Title: Merge Markdown
Author(s): LiXizhi@yeah.net
Date: 2019/3/8
Desc: 
A special context: `<<[]()` is used for merging to take place recursively from the root document. 

```
## root markdown file

<<[merge here](https://keepwork.com/lixizhi/lessons/books/paracraft_01)
<<[merge here](lixizhi/lessons/books/paracraft_02)

```

use the lib:
------------------------------------------------------------
local MergeMarkdown = NPL.load("MergeMarkdown");
-- output file in "temp/MergedMarkdown.md"
-- example 1:
local mmd = MergeMarkdown:new():Init("https://keepwork.com/lixizhi/lessons/books/paracraft01")

-- example 2:
local mmd = MergeMarkdown:new():Init("books/paracraft01.md")
------------------------------------------------------------
]]

local MergeMarkdown = commonlib.inherit(commonlib.gettable("System.Core.ToolBase"), NPL.export())

MergeMarkdown:Signal("finished")

function MergeMarkdown:ctor()
	self.files = {}
end

function MergeMarkdown:Init(root_url)
	self.root_url = root_url;
	self.co = coroutine.create(function()
		self:Parse()
		self:SaveAs();
		self:finished();
	end)
	coroutine.resume(self.co);
end

-- @param address: like "/lixizhi/lessons/books/paracraft" or "https://keepwork.com/lixizhi/lessons/books/paracraft"
-- if it ends with ".md", we will use address as download url instead.  
function MergeMarkdown:GetRawUrlFromAddress(address)
    if(address:match("%.md$")) then
        return address;
    end
    address = address:gsub("^https?://([^/]+)", "")

    local userName, webName = address:match("^/([^/]+)/([^/]+)");
    if (userName and webName)  then
        -- https://git.keepwork.com/gitlab_rls_lixizhi/keepworklessons/raw/master/lixizhi/lessons/books/6_future_edu.md
        local url = format("https://git.keepwork.com/gitlab_rls_%s/keepwork%s/raw/master%s.md", userName, webName, address)
		return url;
    end
	return address;
end

-- @param address: url or file 
-- return text or nil
function MergeMarkdown:GetWikiContent(address)
	local url = self:GetRawUrlFromAddress(address);
	if(url:match("^http")) then
		LOG.std(nil, "info", "MergeMarkdown", "fetching %s", url)
		System.os.GetUrl(url, function(err, msg, data)
			if(err == 200) then
				coroutine.resume(self.co, nil, data);
			else
				LOG.std(nil, "error", "MergeMarkdown", "%s failed with %d", address, err)
				coroutine.resume(self.co, nil);
			end
		end);
		local err, data = coroutine.yield();
		return data;
	else
		local file = ParaIO.open(url, "r")
		if(file) then
			local data = file:GetText(0, -1)
			file:close();
			return data;
		end
	end
end

-- private: 
function MergeMarkdown:Parse()
	local o = {};
	self:AddContent(self.root_url, o)
	self.output = table.concat(o, "\n");
end

function MergeMarkdown:AddContent(url_, o)
	local text = self:GetWikiContent(url_);
	if(text) then
		for line in text:gmatch("([^\r\n]*)\r?\n?") do
			local inline = line:match("^<<(.*)")
			local url;
			if(inline) then
				url = inline:match("%[[^%]]*%]%(([^%)]+)%)")
				if(not url) then
					if(inline:match("^http")) then
						url = inline;
					end
				end
			end
			if(url) then
				self:AddContent(url, o)
			else
				o[#o+1] = line;
			end
		end
	end
end

function MergeMarkdown:SaveAs(filename)
	filename = filename or "temp/MergedMarkdown.md"
	if(self.output) then
		local file = ParaIO.open(filename, "w");
		if(file) then
			file:WriteString(self.output);
			LOG.std(nil, "info", "MergeMarkdown", "%s is generated", filename)
			file:close();
		end
	end
end