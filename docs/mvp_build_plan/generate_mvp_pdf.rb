#!/usr/bin/env ruby
require 'prawn'
require 'prawn/table'

here = File.dirname(__FILE__)
md_path = File.join(here, 'FutureProof_EPM_Budget_MVP_Build_Plan.md')
pdf_path = File.join(here, 'FutureProof_EPM_Budget_MVP_Build_Plan.pdf')
content = File.read(md_path)

# Sanitize chars that aren't in Windows-1252 (default Prawn AFM encoding)
content = content
  .gsub("\u2248", '~')       # ≈
  .gsub("\u2192", '->')      # →
  .gsub("\u2190", '<-')      # ←
  .gsub("\u2264", '<=')      # ≤
  .gsub("\u2265", '>=')      # ≥
  .gsub("\u00A0", ' ')       # nbsp

Prawn::Document.generate(pdf_path,
                         page_size: 'A4',
                         page_layout: :portrait,
                         margin: [ 43.2, 54 ]) do |pdf|
  primary  = '0B3D91'
  accent   = '0066CC'
  dark     = '222222'
  mid      = '555555'
  soft     = 'F4F6FB'

  pdf.font 'Helvetica'

  def flush_paragraph(pdf, buffer, dark)
    return if buffer.empty?
    text = buffer.join(' ')
    text = text.gsub(/\*\*(.+?)\*\*/, '<b>\\1</b>')
    pdf.font_size(10.5) do
      pdf.text text, color: dark, align: :justify, leading: 2.5, inline_format: true
    end
    pdf.move_down(6)
    buffer.clear
  end

  def flush_bullets(pdf, bullets, dark)
    return if bullets.empty?
    pdf.move_down(2)
    pdf.font_size(10.5) do
      bullets.each do |b|
        body = b.gsub(/\*\*(.+?)\*\*/, '<b>\\1</b>')
        pdf.indent(14) do
          pdf.float do
            pdf.text '•', color: dark
          end
          pdf.indent(10) do
            pdf.text body, color: dark, align: :left, leading: 2.5, inline_format: true
          end
        end
        pdf.move_down(3)
      end
    end
    pdf.move_down(4)
    bullets.clear
  end

  lines = content.split("\n")
  i = 0
  para_buf = []
  bullet_buf = []

  while i < lines.length
    line = lines[i]

    # Flush pending buffers on structural breaks
    structural = line.start_with?('#', '|') || line.strip.empty? || line.start_with?('---')
    if structural
      flush_paragraph(pdf, para_buf, dark)
      flush_bullets(pdf, bullet_buf, dark)
    end

    # H1 — document title
    if line.start_with?('# ')
      title = line.sub(/^# /, '')
      pdf.font_size(24) { pdf.text title, color: primary, style: :bold }
      pdf.stroke_color(primary)
      pdf.stroke_horizontal_rule
      pdf.stroke_color('000000')
      pdf.move_down(12)
      i += 1
      next
    end

    if line.start_with?('## ')
      pdf.move_down(10)
      h = line.sub(/^## /, '')
      pdf.font_size(15) { pdf.text h, color: primary, style: :bold }
      pdf.move_down(6)
      i += 1
      next
    end

    if line.start_with?('### ')
      pdf.move_down(6)
      h = line.sub(/^### /, '')
      pdf.font_size(12) { pdf.text h, color: accent, style: :bold }
      pdf.move_down(4)
      i += 1
      next
    end

    if line.strip.empty?
      i += 1
      next
    end

    if line.start_with?('---')
      pdf.move_down(6)
      pdf.stroke_color('CCCCCC')
      pdf.stroke_horizontal_rule
      pdf.stroke_color('000000')
      pdf.move_down(6)
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
      table_data = table_lines.map do |t|
        t.split('|').map(&:strip).reject(&:empty?)
      end
      table_data.delete_at(1) if table_data.length > 1 && table_data[1].all? { |c| c.match?(/^[-:\s]+$/) }
      if table_data.any?
        pdf.move_down(6)
        pdf.table(table_data,
                  header: true,
                  row_colors: [ soft, 'FFFFFF' ],
                  cell_style: { size: 9.5, padding: [ 5, 6 ], text_color: dark, inline_format: true },
                  width: pdf.bounds.width) do |t|
          t.cells.borders = [ :bottom ]
          t.cells.border_width = 0.5
          t.cells.border_color = 'DDDDDD'
          t.row(0).background_color = primary
          t.row(0).text_color = 'FFFFFF'
          t.row(0).font_style = :bold
        end
        pdf.move_down(8)
      end
      next
    end

    # Bullets
    if line =~ /^\s*-\s+/
      body = line.sub(/^\s*-\s+/, '')
      # Bold a leading "**term** —" idiom
      bullet_buf << body
      i += 1
      # Collect continuation lines (indented)
      while i < lines.length && lines[i] =~ /^\s{2,}\S/
        bullet_buf[-1] += ' ' + lines[i].strip
        i += 1
      end
      next
    end

    # Numbered list — render as indented numbered paragraph (no bullet)
    if line =~ /^\s*\d+\.\s+/
      md = line.match(/^\s*(\d+)\.\s+(.*)$/)
      num, body = md[1], md[2]
      flush_bullets(pdf, bullet_buf, dark)
      i += 1
      while i < lines.length && lines[i] =~ /^\s{2,}\S/
        body += ' ' + lines[i].strip
        i += 1
      end
      rendered = body.gsub(/\*\*(.+?)\*\*/, '<b>\\1</b>')
      pdf.font_size(10.5) do
        pdf.indent(14) do
          pdf.float { pdf.text "#{num}.", color: dark }
          pdf.indent(18) { pdf.text rendered, color: dark, align: :left, leading: 2.5, inline_format: true }
        end
      end
      pdf.move_down(3)
      next
    end

    # Regular paragraph — accumulate
    para_buf << line.strip
    i += 1
  end

  flush_paragraph(pdf, para_buf, dark)
  flush_bullets(pdf, bullet_buf, dark)

  # Footer: page numbers + document label
  pdf.number_pages 'FutureProof EPM — Budget MVP Build Plan  •  Page <page> of <total>',
                   at: [ pdf.bounds.left, -20 ],
                   align: :center,
                   size: 8.5,
                   color: mid
end

puts "Generated: #{pdf_path}"
puts "Size: #{File.size(pdf_path) / 1024}KB"
