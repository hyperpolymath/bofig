// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// bofig Documentation Site Generator
// Uses zigzag-ssg for static site generation

const std = @import("std");

/// Site configuration
const SiteConfig = struct {
    title: []const u8 = "Evidence Graph - bofig",
    description: []const u8 = "Infrastructure for pragmatic epistemology",
    base_url: []const u8 = "https://hyperpolymath.github.io/bofig",
    content_dir: []const u8 = "content",
    output_dir: []const u8 = "_site",
    template_dir: []const u8 = "templates",
};

/// Frontmatter structure for content pages
const Frontmatter = struct {
    title: []const u8,
    date: ?[]const u8 = null,
    draft: bool = false,
    template: []const u8 = "default",
    description: ?[]const u8 = null,
    order: u32 = 0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage();
        return;
    }

    const command = args[1];

    if (std.mem.eql(u8, command, "build")) {
        try buildSite(allocator);
    } else if (std.mem.eql(u8, command, "watch")) {
        std.debug.print("Watch mode not yet implemented\n", .{});
    } else if (std.mem.eql(u8, command, "help")) {
        try printUsage();
    } else {
        std.debug.print("Unknown command: {s}\n", .{command});
        try printUsage();
    }
}

fn printUsage() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\bofig-site - Documentation site generator
        \\
        \\Usage: bofig-site <command>
        \\
        \\Commands:
        \\  build    Build the static site
        \\  watch    Watch for changes and rebuild
        \\  help     Show this help message
        \\
        \\The site will be generated in the _site directory.
        \\
    , .{});
}

fn buildSite(allocator: std.mem.Allocator) !void {
    const config = SiteConfig{};
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Building bofig documentation site...\n", .{});
    try stdout.print("  Content: {s}\n", .{config.content_dir});
    try stdout.print("  Output:  {s}\n", .{config.output_dir});

    // Create output directory
    std.fs.cwd().makeDir(config.output_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };

    // Process content files
    var content_dir = try std.fs.cwd().openDir(config.content_dir, .{ .iterate = true });
    defer content_dir.close();

    var file_count: u32 = 0;
    var walker = try content_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const ext = std.fs.path.extension(entry.basename);
        if (!std.mem.eql(u8, ext, ".md")) continue;

        try processMarkdownFile(allocator, config, entry.path);
        file_count += 1;
    }

    try stdout.print("\nProcessed {d} files\n", .{file_count});
    try stdout.print("Site built successfully!\n", .{});
}

fn processMarkdownFile(allocator: std.mem.Allocator, config: SiteConfig, path: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("  Processing: {s}\n", .{path});

    // Read source file
    var content_dir = try std.fs.cwd().openDir(config.content_dir, .{});
    defer content_dir.close();

    const source = try content_dir.readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(source);

    // Parse frontmatter and content
    const parsed = try parseFrontmatter(source);

    // Convert markdown to HTML (basic implementation)
    const html_content = try markdownToHtml(allocator, parsed.content);
    defer allocator.free(html_content);

    // Apply template
    const full_html = try applyTemplate(allocator, config, parsed.frontmatter, html_content);
    defer allocator.free(full_html);

    // Write output file
    const output_path = try std.fmt.allocPrint(allocator, "{s}.html", .{
        std.fs.path.stem(path),
    });
    defer allocator.free(output_path);

    var output_dir = try std.fs.cwd().openDir(config.output_dir, .{});
    defer output_dir.close();

    const file = try output_dir.createFile(output_path, .{});
    defer file.close();
    try file.writeAll(full_html);
}

const ParsedContent = struct {
    frontmatter: Frontmatter,
    content: []const u8,
};

fn parseFrontmatter(source: []const u8) !ParsedContent {
    // Simple frontmatter parser (YAML-style between ---)
    if (!std.mem.startsWith(u8, source, "---\n")) {
        return ParsedContent{
            .frontmatter = Frontmatter{ .title = "Untitled" },
            .content = source,
        };
    }

    const end_marker = std.mem.indexOf(u8, source[4..], "\n---\n");
    if (end_marker == null) {
        return ParsedContent{
            .frontmatter = Frontmatter{ .title = "Untitled" },
            .content = source,
        };
    }

    const frontmatter_text = source[4 .. 4 + end_marker.?];
    const content_start = 4 + end_marker.? + 5;
    const content = source[content_start..];

    // Parse frontmatter fields (basic key: value parsing)
    var frontmatter = Frontmatter{ .title = "Untitled" };

    var lines = std.mem.splitScalar(u8, frontmatter_text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        const colon_pos = std.mem.indexOf(u8, trimmed, ":") orelse continue;
        const key = std.mem.trim(u8, trimmed[0..colon_pos], " \t");
        const value = std.mem.trim(u8, trimmed[colon_pos + 1 ..], " \t\"'");

        if (std.mem.eql(u8, key, "title")) {
            frontmatter.title = value;
        } else if (std.mem.eql(u8, key, "date")) {
            frontmatter.date = value;
        } else if (std.mem.eql(u8, key, "description")) {
            frontmatter.description = value;
        } else if (std.mem.eql(u8, key, "template")) {
            frontmatter.template = value;
        } else if (std.mem.eql(u8, key, "draft")) {
            frontmatter.draft = std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "yes");
        }
    }

    return ParsedContent{
        .frontmatter = frontmatter,
        .content = content,
    };
}

fn markdownToHtml(allocator: std.mem.Allocator, markdown: []const u8) ![]u8 {
    // Basic markdown to HTML conversion
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var lines = std.mem.splitScalar(u8, markdown, '\n');
    var in_code_block = false;
    var in_list = false;

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r");

        // Code blocks
        if (std.mem.startsWith(u8, trimmed, "```")) {
            if (in_code_block) {
                try result.appendSlice("</code></pre>\n");
                in_code_block = false;
            } else {
                try result.appendSlice("<pre><code>");
                in_code_block = true;
            }
            continue;
        }

        if (in_code_block) {
            try result.appendSlice(trimmed);
            try result.append('\n');
            continue;
        }

        // Headers
        if (std.mem.startsWith(u8, trimmed, "# ")) {
            try result.appendSlice("<h1>");
            try result.appendSlice(trimmed[2..]);
            try result.appendSlice("</h1>\n");
        } else if (std.mem.startsWith(u8, trimmed, "## ")) {
            try result.appendSlice("<h2>");
            try result.appendSlice(trimmed[3..]);
            try result.appendSlice("</h2>\n");
        } else if (std.mem.startsWith(u8, trimmed, "### ")) {
            try result.appendSlice("<h3>");
            try result.appendSlice(trimmed[4..]);
            try result.appendSlice("</h3>\n");
        }
        // List items
        else if (std.mem.startsWith(u8, trimmed, "- ") or std.mem.startsWith(u8, trimmed, "* ")) {
            if (!in_list) {
                try result.appendSlice("<ul>\n");
                in_list = true;
            }
            try result.appendSlice("<li>");
            try result.appendSlice(trimmed[2..]);
            try result.appendSlice("</li>\n");
        }
        // Empty line ends list
        else if (trimmed.len == 0) {
            if (in_list) {
                try result.appendSlice("</ul>\n");
                in_list = false;
            }
            try result.appendSlice("\n");
        }
        // Regular paragraph
        else {
            if (in_list) {
                try result.appendSlice("</ul>\n");
                in_list = false;
            }
            try result.appendSlice("<p>");
            try result.appendSlice(trimmed);
            try result.appendSlice("</p>\n");
        }
    }

    if (in_list) {
        try result.appendSlice("</ul>\n");
    }

    return result.toOwnedSlice();
}

fn applyTemplate(allocator: std.mem.Allocator, config: SiteConfig, frontmatter: Frontmatter, content: []const u8) ![]u8 {
    // Basic HTML5 template
    return std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\    <meta charset="UTF-8">
        \\    <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\    <title>{s} | {s}</title>
        \\    <meta name="description" content="{s}">
        \\    <link rel="stylesheet" href="/style.css">
        \\</head>
        \\<body>
        \\    <header>
        \\        <nav>
        \\            <a href="/">Evidence Graph</a>
        \\            <a href="/docs.html">Documentation</a>
        \\            <a href="/api.html">API</a>
        \\            <a href="https://github.com/hyperpolymath/bofig">GitHub</a>
        \\        </nav>
        \\    </header>
        \\    <main>
        \\        <article>
        \\            <h1>{s}</h1>
        \\            {s}
        \\        </article>
        \\    </main>
        \\    <footer>
        \\        <p>&copy; 2025 Evidence Graph Project. Licensed under AGPL-3.0-or-later.</p>
        \\    </footer>
        \\</body>
        \\</html>
        \\
    , .{
        frontmatter.title,
        config.title,
        frontmatter.description orelse config.description,
        frontmatter.title,
        content,
    });
}

test "frontmatter parsing" {
    const source =
        \\---
        \\title: Test Page
        \\date: 2025-01-01
        \\draft: false
        \\---
        \\
        \\# Content here
    ;

    const parsed = try parseFrontmatter(source);
    try std.testing.expectEqualStrings("Test Page", parsed.frontmatter.title);
    try std.testing.expect(!parsed.frontmatter.draft);
}

test "markdown to html" {
    const allocator = std.testing.allocator;

    const markdown = "# Hello\n\nThis is a test.";
    const html = try markdownToHtml(allocator, markdown);
    defer allocator.free(html);

    try std.testing.expect(std.mem.indexOf(u8, html, "<h1>Hello</h1>") != null);
    try std.testing.expect(std.mem.indexOf(u8, html, "<p>This is a test.</p>") != null);
}
