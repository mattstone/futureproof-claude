import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    rows: Array,
    buckets: Array
  }

  connect() {
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  render() {
    this.element.innerHTML = ""
    const rows = this.rowsValue
    const buckets = this.bucketsValue
    if (!rows.length) {
      this.element.innerHTML = '<div class="dashboard-empty">No pipeline data.</div>'
      return
    }

    const width = this.element.clientWidth || 720
    const rowHeight = 44
    const headerHeight = 24
    const margin = { top: headerHeight, right: 80, bottom: 16, left: 130 }
    const innerW = width - margin.left - margin.right
    const innerH = rows.length * rowHeight
    const height = innerH + margin.top + margin.bottom + 24 // legend space

    const maxTotal = d3.max(rows, r => r.total) || 1
    const x = d3.scaleLinear().domain([0, maxTotal]).range([0, innerW])

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("class", "trend-chart-svg")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // X axis
    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(5))
      .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
      .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
      .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))

    // Each row
    rows.forEach((row, ri) => {
      const y = ri * rowHeight + 8
      const barH = rowHeight - 16

      // Stage label
      g.append("text")
        .attr("x", -12)
        .attr("y", y + barH / 2 + 4)
        .attr("text-anchor", "end")
        .attr("font-size", 12)
        .attr("font-weight", 600)
        .attr("fill", "#0f172a")
        .text(row.stage)

      // Stacked segments
      let xCursor = 0
      row.buckets.forEach(bucket => {
        if (!bucket.count) return
        const w = x(bucket.count) - x(0)
        g.append("rect")
          .attr("x", xCursor)
          .attr("y", y)
          .attr("width", w)
          .attr("height", barH)
          .attr("fill", bucket.color)
          .append("title")
          .text(`${row.stage} · ${bucket.label}: ${bucket.count} applications`)

        if (w > 22) {
          g.append("text")
            .attr("x", xCursor + w / 2)
            .attr("y", y + barH / 2 + 4)
            .attr("text-anchor", "middle")
            .attr("font-size", 11)
            .attr("font-weight", 600)
            .attr("fill", "#fff")
            .text(bucket.count)
        }
        xCursor += w
      })

      // Total at end
      g.append("text")
        .attr("x", xCursor + 8)
        .attr("y", y + barH / 2 + 4)
        .attr("font-size", 11)
        .attr("font-weight", 600)
        .attr("fill", "#475569")
        .text(`${row.total} total`)
    })

    // Legend
    const legend = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top + innerH + 28})`)

    let legendX = 0
    buckets.forEach(b => {
      const grp = legend.append("g").attr("transform", `translate(${legendX},0)`)
      grp.append("rect").attr("width", 12).attr("height", 12).attr("fill", b.color).attr("rx", 2)
      grp.append("text")
        .attr("x", 18).attr("y", 10)
        .attr("font-size", 11).attr("fill", "#475569")
        .text(b.label)
      legendX += 100
    })
  }
}
