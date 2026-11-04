local M = {}

function M.render_svg(plantuml_jar)
    local source_file = vim.api.nvim_buf_get_name(0)
    if source_file == "" then
      source_file = "temp_diagram"
    end
    if not plantuml_jar then
        vim.notify("Set plantuml_jar in diawolf.setup()")
        return
    end

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local source = table.concat(lines, "\n")
    if vim.bo.endofline then
        source = source .. "\n"
    end

    local output_file = vim.fn.fnamemodify(source_file, ":r") .. ".svg"

    vim.system({
        "java",
        "-jar",
        plantuml_jar,
        "-tsvg",
        "-pipe",
    }, {
        stdin = source,
        text = true,
    }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then
                vim.notify(result.stderr, vim.log.levels.ERROR)
                return
            end

            local output_lines = vim.split(result.stdout, "\n", {
                plain = true,
                trimempty = true,
            })
            local write_result = vim.fn.writefile(output_lines, output_file)

            if write_result ~= 0 then
                vim.notify("Could not write SVG: " .. output_file, vim.log.levels.ERROR)
                return
            end

            vim.notify("Rendered SVG: " .. output_file)
        end)
    end)
end

return M
