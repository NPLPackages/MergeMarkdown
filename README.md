# MergeMarkdown
merge a set of markdown files into one according to special notations.


A special syntax: `<<[]()` is used for merging to take place recursively from the root document. 

```
## root markdown file

<<[merge point1](https://keepwork.com/lixizhi/lessons/books/paracraft_01)
<<[merge point2](lixizhi/lessons/books/paracraft_02)

```


## how to use the lib:
git clone to `npl_packages/` folder and then run:

```lua
local MergeMarkdown = NPL.load("MergeMarkdown");
-- output file in "temp/MergedMarkdown.md"
-- example 1:
local mmd = MergeMarkdown:new():Init("https://keepwork.com/lixizhi/lessons/books/paracraft01")
```

## Examples:
Please note, `keepwork.com` url is supported. If your file is not on keepwork, it has to ends with `*.md`

- https://keepwork.com/lixizhi/lessons/books/paracraft01
- https://keepwork.com/lixizhi/lessons/books/paracraft_preview_gen
