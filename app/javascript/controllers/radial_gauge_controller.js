import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    value: Number,
    max: Number,
    unit: String,
    label: String,
    detail: String,
    higherIsBetter: Boolean,
    warningAt: Number,
    criticalAt: Number
  }

  connect() {
    this.render()
  }

  colorForValue() {
    const v = this.valueValue
    const higher = this.higherIsBetterValue

    if (higher) {
      if (v <= this.criticalAtValue) return "#dc2626"
      if (v <= this.warningAtValue) return "#f59e0b"
      return "#16a34a"
    } else {
      if (v >= this.criticalAtValue) return "#dc2626"
      if (v >= this.warningAtValue) return "#f59e0b"
      return "#16a34a"
    }
  }

  render() {
    this.element.innerHTML = ""

    const width = this.element.clientWidth || 200
    const height = 120
    const radius = Math.min(width, height * 1.6) / 2 - 8
    const cx = width / 2
    const cy = height - 12

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)

    const startAngle = -Math.PI / 2
    const endAngle = Math.PI / 2

    // Background arc (track)
    const track = d3.arc()
      .innerRadius(radius - 14)
      .outerRadius(radius)
      .startAngle(startAngle)
      .endAngle(endAngle)

    svg.append("path")
      .attr("d", track())
      .attr("transform", `translate(${cx},${cy})`)
      .attr("fill", "#e2e8f0")

    // Foreground arc (value)
    const proportion = Math.max(0, Math.min(1, this.valueValue / this.maxValue))
    const valueAngle = startAngle + (endAngle - startAngle) * proportion

    const valueArc = d3.arc()
      .innerRadius(radius - 14)
      .outerRadius(radius)
      .startAngle(startAngle)
      .endAngle(valueAngle)
      .cornerRadius(7)

    const color = this.colorForValue()

    svg.append("path")
      .attr("d", valueArc())
      .attr("transform", `translate(${cx},${cy})`)
      .attr("fill", color)

    // Tick marks at 25/50/75% of max
    const ticks = [0.25, 0.5, 0.75]
    ticks.forEach(t => {
      const angle = startAngle + (endAngle - startAngle) * t
      const x1 = cx + (radius - 18) * Math.cos(angle - Math.PI / 2)
      const y1 = cy + (radius - 18) * Math.sin(angle - Math.PI / 2)
      const x2 = cx + (radius - 6) * Math.cos(angle - Math.PI / 2)
      const y2 = cy + (radius - 6) * Math.sin(angle - Math.PI / 2)
      svg.append("line")
        .attr("x1", x1).attr("y1", y1).attr("x2", x2).attr("y2", y2)
        .attr("stroke", "#fff").attr("stroke-width", 1.5)
    })

    // Center value label
    svg.append("text")
      .attr("x", cx)
      .attr("y", cy - 14)
      .attr("text-anchor", "middle")
      .attr("font-size", "26px")
      .attr("font-weight", "700")
      .attr("fill", "#0f172a")
      .text(`${this.valueValue}${this.unitValue}`)

    // Max indicator
    svg.append("text")
      .attr("x", cx)
      .attr("y", cy + 6)
      .attr("text-anchor", "middle")
      .attr("font-size", "10px")
      .attr("fill", "#94a3b8")
      .text(`/ ${this.maxValue}${this.unitValue}`)
  }
}
