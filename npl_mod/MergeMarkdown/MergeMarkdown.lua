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
One can use `pandoc` to further convert md file to docx
```
pandoc -s -o doc.docx MergedMarkdown.md
pandoc -s -o doc.pdf MergedMarkdown.md
```

use the lib:
------------------------------------------------------------
local MergeMarkdown = NPL.load("MergeMarkdown");
-- output file in "temp/MergedMarkdown.md"
-- example 1:
local mmd = MergeMarkdown:new():Init("https://keepwork.com/lixizhi/lessons/books/paracraft01", {
	isConvertToImage = true,
	isRenameImageByNumber = true,
	exportImageToFolder = false,
})

-- example 2:
local mmd = MergeMarkdown:new():Init("books/paracraft01.md")
------------------------------------------------------------
]]

local MergeMarkdown = commonlib.inherit(commonlib.gettable("System.Core.ToolBase"), NPL.export())

MergeMarkdown:Property({"imageFolder", "images/"});
MergeMarkdown:Signal("finished")

function MergeMarkdown:ctor()
	self.files = {}
end

--[[
@param options: nil or a table of options:
{
	isConvertToImage = true,  -- whether to convert all @BigFile to ~[]() wiki image
	isRenameImageByNumber = true, -- we will rename all images to ~[image001]()
	exportImageToFolder = true, -- we will export all images to ./images folder with image001.png or jpg as file name.
}
]]
function MergeMarkdown:Init(root_url, options)
	self.root_url = root_url;
	self.options = options or {}
	self.co = coroutine.create(function()
		self:Parse()
		self:SaveAs();
		self:finished();
	end)
	coroutine.resume(self.co);
end

function MergeMarkdown:IsConvertBigFileToWikiImage()
	return self.options.isConvertToImage;
end

function MergeMarkdown:IsRenameImageByNumber()
	return self.options.isRenameImageByNumber;
end

function MergeMarkdown:IsExportImageToFolder()
	return self.options.exportImageToFolder;
end

-- @param address: like "/lixizhi/lessons/books/paracraft" or "https://keepwork.com/lixizhi/lessons/books/paracraft"
-- @param repoPrefix: default to "", it can also be "keepwork" for older project. 
-- if it ends with ".md", we will use address as download url instead.  
function MergeMarkdown:GetRawUrlFromAddress(address, repoPrefix)
    if(address:match("%.md$")) then
        return address;
    end
    address = address:gsub("^https?://([^/]+)", "")

    local userName, webName = address:match("^/([^/]+)/([^/]+)");
    if (userName and webName)  then
        -- https://git.keepwork.com/gitlab_rls_lixizhi/keepworklessons/raw/master/lixizhi/lessons/books/6_future_edu.md
        local url = format("https://git.keepwork.com/gitlab_rls_%s/%s%s/raw/master%s.md", userName, repoPrefix or "", webName, address)
		return url;
    end
	return address;
end

-- @param address: url or file 
-- @param repoPrefix: default to "", it can also be "keepwork" for older project. 
-- return text or nil
function MergeMarkdown:GetWikiContent(address, repoPrefix)
	local url = self:GetRawUrlFromAddress(address, repoPrefix);
	if(url:match("^http")) then
		LOG.std(nil, "info", "MergeMarkdown", "fetching %s", url)
		System.os.GetUrl(url, function(err, msg, data)
			if(err == 200) then
				coroutine.resume(self.co, nil, data);
			else
				LOG.std(nil, "warn", "MergeMarkdown", "%s failed with %d", url, err)
				coroutine.resume(self.co, nil);
			end
		end);
		local data = self:Yield();
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

function MergeMarkdown:Yield(...)
	local err, data = coroutine.yield(...);
	if(err) then
		LOG.std(nil, "error", "MergeMarkdown", data)
	else
		return data;
	end
end


function MergeMarkdown:GetImageRelativePath(url, name)
	local ext = url:match("(%.%w+)$")
	if(ext) then
		name = (name or "image")..ext;
	end
	name = self.imageFolder .. name;
	return name;
end

-- @return nil or image path like "image/name"
function MergeMarkdown:FetchImage(url, destDiskFilename)
	url = url:gsub("(#.*)", "")
	local ls = System.localserver.CreateStore();
	if(ls) then
		local hasResult;
		ls:GetFile(nil, url, function(entry)
			if(entry and entry.entry and entry.entry.url and entry.payload and entry.payload.cached_filepath) then
				ParaIO.CopyFile(entry.payload.cached_filepath, destDiskFilename, true);
				LOG.std(nil, "info", "MergeMarkdown", "copy image to %s from url: %s", destDiskFilename, url)
			else
				LOG.std(nil, "warn", "MergeMarkdown", "%s failed to fetch image", url)
			end
			if(coroutine.status(self.co) == "suspended") then
				coroutine.resume(self.co, nil);
			end
			hasResult = true;
		end);
		if(not hasResult) then
			self:Yield();
		end
	end
end


-- private: 
function MergeMarkdown:Parse()
	local o = {};
	self:AddContent(self.root_url, o)

	if(self:IsConvertBigFileToWikiImage()) then
		local o2 = {}
		local i=1;
		while(i<=#o) do
			local line = o[i];
			if(line:match("^```@BigFile")) then
				local url, name;
				for k=1, 100 do
					i = i + 1;
					line = o[i];
					if(line:match("^```")) then
						break;
					else
						url = url or line:match("^%s*src:%s'?([^']+)'?");
						name = name or line:match("^%s*filename:%s'?([^']+)'?");
					end
				end
				if(url and name) then
					o2[#o2+1] = format("![%s](%s)", name, url);	
				end
			else
				o2[#o2+1] = line;
			end
			i = i + 1;
		end
		o = o2;
	end
	if(self:IsRenameImageByNumber()) then
		local exportImage = self:IsExportImageToFolder()
		
		local images = {};
		for i=1, #o do 
			local line = o[i];
			local name, url, text = line:match("^!%[([^%]]*)]%(([^%)]+)%)(.*)")
			if(name and url) then
				local image = {name=name, url=url};
				images[#images+1] = image;
				local name = string.format("image%03d", #images);
				if(exportImage) then
					image.relativePath = self:GetImageRelativePath(url, name)
					url = image.relativePath;
				end
				o[i] = string.format("![%s](%s)%s", name, url, text);	
			end
		end
		self.images = images;
		LOG.std(nil, "info", "MergeMarkdown", "%s total images", #images)
	end

	self.output = table.concat(o, "\n");
end

function MergeMarkdown:AddContent(url_, o)
	local text = self:GetWikiContent(url_) or self:GetWikiContent(url_, "keepwork");
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
	else
		LOG.std(nil, "error", "MergeMarkdown", "%s failed to add content", url_)
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
			
		if(self:IsExportImageToFolder() and self.images) then
			local parentDir = filename:gsub("[^/\\]+$", "")
			local imageFolder = parentDir..self.imageFolder
			ParaIO.CreateDirectory(imageFolder);
			ParaIO.DeleteFile(imageFolder.."*.*")
			for _, image in ipairs(self.images) do
				self:FetchImage(image.url, parentDir..image.relativePath);
			end
		end
	end
end
