--[[
Title: Merge Markdown
Author(s): LiXizhi@yeah.net
Date: 2019/3/8
Desc: 
A special context: `<<[]()` is required for merging to take place. 

```
## root markdown file

<<[merge here](https://keepwork.com/lixizhi/lessons/books/paracraft_01)
<<[merge here](lixizhi/lessons/books/paracraft_02)

```

use the lib:
------------------------------------------------------------
local MergeMarkdown = NPL.load("MergeMarkdown");
local mmd = MergeMarkdown:new():Init("https://keepwork.com/lixizhi/lessons/books/paracraft01")
mmd:SaveAs("temp/MergedMarkdown.md")
------------------------------------------------------------
]]

local MergeMarkdown = commonlib.inherit(nil, NPL.export())


function MergeMarkdown:ctor()
	self.files = {}
end

function MergeMarkdown:Init(root_url)
end

-- @param address: like "/lixizhi/lessons/books/paracraft" or "https://keepwork.com/lixizhi/lessons/books/paracraft"
-- if it ends with ".md", we will use address as download url instead.  
function MergeMarkdown:GetRawUrlFromAddress(address)
    if(address:match("%.md$")) then
        return address;
    end
    address = address:gsub("%https?://[^/]&", "")

    local userName, webName = address:match("^/([^/]+)/([^/]+)");
    if (userName and webName)  then
        -- https://git.keepwork.com/gitlab_rls_lixizhi/keepworklessons/raw/master/lixizhi/lessons/books/6_future_edu.md
        local url = format("https://git.keepwork.com/gitlab_rls_%s/keepwork%s/raw/master%s.md", userName, webName, address)
    end
end

function MergeMarkdown:GetWikiContent(address)
end
