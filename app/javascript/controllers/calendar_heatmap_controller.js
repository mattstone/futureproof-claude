import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    days: Array,
    max: Number,
    total: Number
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
    const days = this.daysValue.map(d => ({ ...d, dateObj: new Date(d.date) }))
    if (!days.length) return

    const cellSize = 12
    const gap = 2
    const labelWidth = 30
    const labelHeight = 18
    const weeks = Math.ceil(days.length / 7) + 1
    const width = labelWidth + weeks * (cellSize + gap)
    const height = labelHeight + 7 * (cellSize + gap)

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("class", "trend-chart-svg")

    const max = Math.max(this.maxValue, 1)
    const color = d3.scaleSequential([0, max], d3.interpolateBlues)

    // Compute week index relative to first sunday before first day
    const firstDate = days[0].dateObj
    const firstSunday = new Date(firstDate)
    firstSunday.setDate(firstDate.getDate() - firstDate.getDay())

    const weekIndex = (d) => {
      const diffMs = d.dateObj - firstSunday
      return Math.floor(diffMs / (1000 * 60 * 60 * 24 * 7))
    }

    // Day-of-week labels
    const dows = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    dows.forEach((d, i) => {
      if (i % 2 === 1) return // show every other to reduce clutter
      svg.append("text")
        .attr("x", labelWidth - 4)
        .attr("y", labelHeight + i * (cellSize + gap) + cellSize - 2)
        .attr("text-anchor", "end")
        .attr("font-size", 9)
        .attr("fill", "#94a3b8")
        .text(d)
    })

    // Month labels
    let lastMonth = -1
    days.forEach(d => {
      const m = d.dateObj.getMonth()
      if (m !== lastMonth && d.dateObj.getDate() <= 7) {
        const wi = weekIndex(d)
        svg.append("text")
          .attr("x", labelWidth + wi * (cellSize + gap))
          .attr("y", labelHeight - 4)
          .attr("font-size", 10)
          .attr("font-weight", 600)
          .attr("fill", "#475569")
          .text(d3.timeFormat("%b")(d.dateObj))
        lastMonth = m
      }
    })

    // Cells
    svg.append("g")
      .selectAll("rect")
      .data(days)
      .join("rect")
      .attr("x", d => labelWidth + weekIndex(d) * (cellSize + gap))
      .attr("y", d => labelHeight + d.dateObj.getDay() * (cellSize + gap))
      .attr("width", cellSize)
      .attr("height", cellSize)
      .attr("rx", 2)
      .attr("fill", d => d.count === 0 ? "#f1f5f9" : color(d.count))
      .append("title")
      .text(d => `${d.date}: ${d.count} application${d.count === 1 ? "" : "s"}`)
  }
}
