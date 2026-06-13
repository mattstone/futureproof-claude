#!/usr/bin/env ruby
require 'prawn'
require 'prawn/table'

# Read the markdown file
markdown_file = 'FutureProof_EPM_Technical_Architecture.md'
content = File.read(markdown_file)

# Create PDF
Prawn::Document.generate('FutureProof_EPM_Technical_Architecture.pdf',
                        page_size: 'A4',
                        page_layout: :portrait,
                        margin: [ 0.5.in, 0.75.in ]) do |pdf|
  # Define colors
  primary_blue = '0066CC'
  dark_gray = '333333'
  light_gray = 'F9F9F9'

  # Set default font
  pdf.font 'Helvetica'

  # Parse and render content
  lines = content.split("\n")
  i = 0

  while i < lines.length
    line = lines[i]

    # Title (h1)
    if line.start_with?('# ')
      pdf.move_down(20) if pdf.cursor < pdf.bounds.top - 50
      title = line.sub(/^# /, '')
      pdf.font_size(28) { pdf.text title, color: primary_blue, style: :bold }
      pdf.stroke_horizontal_rule
      pdf.move_down(10)
      i += 1
      next
    end

    # Section heading (h2)
    if line.start_with?('## ')
      pdf.move_down(15)
      heading = line.sub(/^## /, '')
      pdf.font_size(16) { pdf.text heading, color: primary_blue, style: :bold }
      pdf.move_down(8)
      i += 1
      next
    end

    # Subsection (h3)
    if line.start_with?('### ')
      pdf.move_down(10)
      subheading = line.sub(/^### /, '')
      pdf.font_size(13) { pdf.text subheading, style: :bold, color: dark_gray }
      pdf.move_down(5)
      i += 1
      next
    end

    # Skip empty lines
    if line.strip.empty?
      i += 1
      next
    end

    # Skip horizontal rules
    if line.start_with?('---')
      pdf.move_down(10)
      pdf.stroke_horizontal_rule
      pdf.move_down(10)
      i += 1
      next
    end

    # Tables
    if line.start_with?('|')
      table_lines = []
      while i < lines.length && lines[i].start_with?('|')
        table_lines << lines[i]
        i += 1
      end

      # Parse table
      table_data = []
      table_lines.each do |tline|
        cells = tline.split('|').map(&:strip).reject(&:empty?)
        table_data << cells
      end

      # Skip header separator
      if table_data.length > 1
        table_data.delete_at(1)
      end

      if table_data.any?
        pdf.move_down(10)
        pdf.table(table_data,
                 header: true,
                 row_colors: [ light_gray, 'FFFFFF' ],
                 width: pdf.bounds.width) do |table|
          table.cells.borders = [ :bottom ]
          table.cells.border_width = 1
          table.cells.border_color = 'CCCCCC'
          table.header_row.background_color = primary_blue
          table.header_row.text_color = 'FFFFFF'
          table.header_row.font_style = :bold
          table.column(0).width = 100
        end
        pdf.move_down(10)
      end
      next
    end

    # Regular paragraphs
    if line.length > 0
      pdf.font_size(10) do
        pdf.text line, color: dark_gray, align: :left, leading: 2
      end
      pdf.move_down(4)
    end

    i += 1
  end

  # Footer on each page
  pdf.number_pages '<page>/<total>',
                   at: [ pdf.bounds.right - 50, -20 ],
                   align: :right,
                   size: 9,
                   color: '999999'
end

puts "✅ PDF generated: FutureProof_EPM_Technical_Architecture.pdf"
