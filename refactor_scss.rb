#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

file_path = 'app/assets/stylesheets/application.scss'
content = File.read(file_path)

# 1. We will add the CSS Custom properties logic at the very top of the file
css_vars = <<~CSS
  :root, :root[data-theme="os"] {
    @media (prefers-color-scheme: light) {
      --bg-dark: #f1f5f9;
      --bg-darker: #f8fafc;
      --bg-surface: #ffffff;
      --card-bg: #ffffff;
      --card-bg-solid: #ffffff;
      --text-main: #0f172a;
      --text-muted: #475569;
      --text-dim: #64748b;
      --accent-cyan: #0891b2;
      --accent-cyan-hover: #0e7490;
      --accent-orange: #ea580c;
      --accent-gold: #d97706;
      --accent-green: #059669;
      --accent-green-hover: #047857;
      --primary-color: #0891b2;
      --primary-hover: #0e7490;
      --secondary-color: #4f46e5;
      --star-color: #d97706;
      --danger-color: #dc2626;
      --danger-hover-color: #b91c1c;

      --rgb-inverse: 0, 0, 0;
      --border-subtle: rgba(0, 0, 0, 0.1);
      --border-medium: rgba(0, 0, 0, 0.15);
    }

    @media (prefers-color-scheme: dark) {
      --bg-dark: #07090e;
      --bg-darker: #0b0f19;
      --bg-surface: #1a2035;
      --card-bg: #1a2035;
      --card-bg-solid: #1f2940;
      --text-main: #f8fafc;
      --text-muted: #94a3b8;
      --text-dim: #64748b;
      --accent-cyan: #06b6d4;
      --accent-cyan-hover: #0891b2;
      --accent-orange: #f97316;
      --accent-gold: #fbbf24;
      --accent-green: #10b981;
      --accent-green-hover: #059669;
      --primary-color: #06b6d4;
      --primary-hover: #0891b2;
      --secondary-color: #6366f1;
      --star-color: #fbbf24;
      --danger-color: #ef4444;
      --danger-hover-color: #f87171;

      --rgb-inverse: 255, 255, 255;
      --border-subtle: rgba(255, 255, 255, 0.05);
      --border-medium: rgba(255, 255, 255, 0.08);
    }
  }

  :root[data-theme="light"] {
    --bg-dark: #f1f5f9;
    --bg-darker: #f8fafc;
    --bg-surface: #ffffff;
    --card-bg: #ffffff;
    --card-bg-solid: #ffffff;
    --text-main: #0f172a;
    --text-muted: #475569;
    --text-dim: #64748b;
    --accent-cyan: #0891b2;
    --accent-cyan-hover: #0e7490;
    --accent-orange: #ea580c;
    --accent-gold: #d97706;
    --accent-green: #059669;
    --accent-green-hover: #047857;
    --primary-color: #0891b2;
    --primary-hover: #0e7490;
    --secondary-color: #4f46e5;
    --star-color: #d97706;
    --danger-color: #dc2626;
    --danger-hover-color: #b91c1c;

    --rgb-inverse: 0, 0, 0;
    --border-subtle: rgba(0, 0, 0, 0.1);
    --border-medium: rgba(0, 0, 0, 0.15);
  }

  :root[data-theme="dark"] {
    --bg-dark: #07090e;
    --bg-darker: #0b0f19;
    --bg-surface: #1a2035;
    --card-bg: #1a2035;
    --card-bg-solid: #1f2940;
    --text-main: #f8fafc;
    --text-muted: #94a3b8;
    --text-dim: #64748b;
    --accent-cyan: #06b6d4;
    --accent-cyan-hover: #0891b2;
    --accent-orange: #f97316;
    --accent-gold: #fbbf24;
    --accent-green: #10b981;
    --accent-green-hover: #059669;
    --primary-color: #06b6d4;
    --primary-hover: #0891b2;
    --secondary-color: #6366f1;
    --star-color: #fbbf24;
    --danger-color: #ef4444;
    --danger-hover-color: #f87171;

    --rgb-inverse: 255, 255, 255;
    --border-subtle: rgba(255, 255, 255, 0.05);
    --border-medium: rgba(255, 255, 255, 0.08);
  }
CSS

# Map SCSS variables to CSS variables
scss_vars_map = {
  '$bg-dark' => 'var(--bg-dark)',
  '$bg-darker' => 'var(--bg-darker)',
  '$bg-surface' => 'var(--bg-surface)',
  '$card-bg' => 'var(--card-bg)',
  '$card-bg-solid' => 'var(--card-bg-solid)',
  '$card-border' => 'var(--border-subtle)',
  '$text-main' => 'var(--text-main)',
  '$text-muted' => 'var(--text-muted)',
  '$text-dim' => 'var(--text-dim)',
  '$accent-cyan' => 'var(--accent-cyan)',
  '$accent-cyan-hover' => 'var(--accent-cyan-hover)',
  '$accent-orange' => 'var(--accent-orange)',
  '$accent-gold' => 'var(--accent-gold)',
  '$accent-green' => 'var(--accent-green)',
  '$accent-green-hover' => 'var(--accent-green-hover)',
  '$primary-color' => 'var(--primary-color)',
  '$primary-hover' => 'var(--primary-hover)',
  '$secondary-color' => 'var(--secondary-color)',
  '$star-color' => 'var(--star-color)'
}

# Apply the SCSS variable updates
scss_vars_map.each do |scss_var, css_var|
  # Replace the variable definition to point to the CSS variable
  # This makes any remaining use of the SCSS variable work correctly
  content.gsub!(/^\s*#{Regexp.escape(scss_var)}\s*:\s*#[0-9a-fA-F]+;/, "#{scss_var}: #{css_var};")
  content.gsub!(/^\s*#{Regexp.escape(scss_var)}\s*:\s*rgba\([^)]+\);/, "#{scss_var}: #{css_var};")
end

# Deal with color.adjust calls manually
content.gsub!('color.adjust($accent-orange, $lightness: 12%)', 'var(--accent-orange)') # Close enough
content.gsub!('color.adjust($accent-orange, $lightness: 6%)', 'var(--accent-orange)') # Close enough
content.gsub!('color.adjust(#ef4444, $lightness: 6%)', 'var(--danger-hover-color)')
content.gsub!('color.adjust(#818cf8, $lightness: 10%)', '#818cf8') # Hardcoded fallback
content.gsub!('color.adjust(#1e1b4b, $lightness: 6%)', '#1e1b4b')
content.gsub!('color.adjust(#0f172a, $lightness: 6%)', '#0f172a')

# Replace exact colors in the rest of the file
content.gsub!(/#ffffff/i, 'var(--text-main)')
content.gsub!(/#fff\b/i, 'var(--text-main)')
content.gsub!(/#000000/i, 'var(--bg-darker)')
content.gsub!(/#000\b/i, 'var(--bg-darker)')
content.gsub!(/#07090e/i, 'var(--bg-dark)')
content.gsub!(/#0b0f19/i, 'var(--bg-darker)')
content.gsub!(/#1a2035/i, 'var(--card-bg)')
content.gsub!(/#1f2940/i, 'var(--card-bg-solid)')
content.gsub!(/#f8fafc/i, 'var(--text-main)')
content.gsub!(/#94a3b8/i, 'var(--text-muted)')
content.gsub!(/#64748b/i, 'var(--text-dim)')
content.gsub!(/#06b6d4/i, 'var(--accent-cyan)')
content.gsub!(/#0891b2/i, 'var(--accent-cyan-hover)')
content.gsub!(/#f97316/i, 'var(--accent-orange)')
content.gsub!(/#fbbf24/i, 'var(--accent-gold)')
content.gsub!(/#10b981/i, 'var(--accent-green)')
content.gsub!(/#059669/i, 'var(--accent-green-hover)')
content.gsub!(/#6366f1/i, 'var(--secondary-color)')
content.gsub!(/#ef4444/i, 'var(--danger-color)')
content.gsub!(/#dc2626/i, 'var(--danger-hover-color)')
content.gsub!(/#f87171/i, 'var(--danger-hover-color)')

# Specific RGBA replacements for overlays / borders
# Replace rgba(255, 255, 255, X) with rgba(var(--rgb-inverse), X)
content.gsub!(/rgba\(255,\s*255,\s*255,\s*([0-9.]+)\)/) do |_match|
  "rgba(var(--rgb-inverse), #{Regexp.last_match(1)})"
end

# Find the location of the first SCSS variable definition and insert CSS vars above it
first_var_idx = content.index('$bg-dark:')
if first_var_idx
  content.insert(first_var_idx, "#{css_vars}\n")
else
  content = "#{css_vars}\n#{content}"
end

File.write(file_path, content)
puts 'Successfully refactored SCSS variables.'
