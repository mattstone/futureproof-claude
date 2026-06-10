import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    rows: Array,
    metrics: Array
  }

  connect() {
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  colorFor(cell) {
    // Neutral metrics use a blue scale (informational); polarized metrics use traffic-light
    if (cell.polarity === "neutral") {
      return d3.interpolateBlues(0.2 + cell.normalized * 0.7)
    }
    // 0 = good (green), 1 = bad (red), via amber midpoint
    const interp = d3.interpolateRgbBasis(["#16a34a", "#f59e0b", "#dc2626"])
    return interp(cell.normalized)
  }

  formatValue(cell) {
    if (cell.value == null) return "—"
    if (cell.format === "percent") return `${cell.value}%`
    if (cell.format === "currency") return d3.format("$,.0f")(cell.value)
    return d3.format(",")(cell.value)
  }

  render() {
    this.element.innerHTML = ""
    const rows = this.rowsValue
    const metrics = this.metricsValue
    if (!rows.length) {
      this.element.innerHTML = '<div class="dashboard-empty">No cohort data yet.</div>'
      return
    }

    const cellWidth = 160
    const cellHeight = 36
    const labelWidth = 90
    const headerHeight = 32
    const width = labelWidth + cellWidth * metrics.length
    const height = headerHeight + cellHeight * rows.length

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)

    // Column headers
    metrics.forEach((m, i) => {
      svg.append("text")
        .attr("x", labelWidth + i * cellWidth + cellWidth / 2)
        .attr("y", headerHeight - 10)
        .attr("text-anchor", "middle")
        .attr("font-size", "12px")
        .attr("font-weight", "600")
        .attr("fill", "#475569")
        .text(m.label)
    })

    // Rows
    rows.forEach((row, ri) => {
      const y = headerHeight + ri * cellHeight

      // Row label
      svg.append("text")
        .attr("x", labelWidth - 10)
        .attr("y", y + cellHeight / 2 + 4)
        .attr("text-anchor", "end")
        .attr("font-size", "12px")
        .attr("font-weight", "600")
        .attr("fill", "#0f172a")
        .text(row.label)

      // Cells
      row.cells.forEach((cell, ci) => {
        const x = labelWidth + ci * cellWidth
        const fill = this.colorFor(cell)

        const g = svg.append("g")
          .attr("transform", `translate(${x},${y})`)

        g.append("rect")
          .attr("x", 1)
          .attr("y", 1)
          .attr("width", cellWidth - 2)
          .attr("height", cellHeight - 2)
          .attr("fill", fill)
          .attr("rx", 3)

        const textColor = cell.polarity === "neutral" || cell.normalized < 0.6 ? "#0f172a" : "#fff"

        g.append("text")
          .attr("x", cellWidth / 2)
          .attr("y", cellHeight / 2 + 4)
          .attr("text-anchor", "middle")
          .attr("font-size", "13px")
          .attr("font-weight", "600")
          .attr("fill", textColor)
          .text(this.formatValue(cell))

        g.append("title").text(`${row.label} · ${cell.label}: ${this.formatValue(cell)}`)
      })
    })
  }
}
