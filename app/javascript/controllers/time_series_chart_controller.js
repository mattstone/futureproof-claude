import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    type: String,           // "bar" | "area" | "combo"
    series: Array,          // [{label, value}] or [{label, monthly, cumulative}] for combo
    valueFormat: String,    // "integer" | "currency"
    color: String,          // hex
    secondaryColor: String  // hex for combo line
  }

  connect() {
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  formatValue(v) {
    if (this.valueFormatValue === "currency") return d3.format("$,.2s")(v).replace("G", "B")
    return d3.format(",")(v)
  }

  formatTooltip(v) {
    if (this.valueFormatValue === "currency") return d3.format("$,.0f")(v)
    return d3.format(",")(v)
  }

  render() {
    this.element.innerHTML = ""
    const series = this.seriesValue
    if (!series.length) {
      this.element.innerHTML = '<div class="dashboard-empty">No data yet.</div>'
      return
    }

    const width = this.element.clientWidth || 360
    const height = 200
    const margin = { top: 12, right: 16, bottom: 28, left: 56 }
    const innerW = width - margin.left - margin.right
    const innerH = height - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("class", "trend-chart-svg")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const labels = series.map(d => d.label)
    const x = d3.scaleBand()
      .domain(labels)
      .range([0, innerW])
      .padding(this.typeValue === "bar" ? 0.3 : 0.05)

    const primaryColor = this.colorValue || "#2563eb"
    const secondaryColor = this.secondaryColorValue || "#0f172a"

    if (this.typeValue === "bar") {
      const values = series.map(d => Number(d.value) || 0)
      const yMax = d3.max(values) || 1
      const y = d3.scaleLinear().domain([0, yMax * 1.1]).nice().range([innerH, 0])

      this.drawAxes(g, x, y, innerH, labels.length)

      g.append("g")
        .selectAll("rect")
        .data(series)
        .join("rect")
        .attr("x", d => x(d.label))
        .attr("y", d => y(Number(d.value) || 0))
        .attr("width", x.bandwidth())
        .attr("height", d => innerH - y(Number(d.value) || 0))
        .attr("fill", primaryColor)
        .attr("rx", 2)
        .append("title")
        .text(d => `${d.label}: ${this.formatTooltip(d.value)}`)
    }

    if (this.typeValue === "area") {
      const values = series.map(d => Number(d.value) || 0)
      const yMax = d3.max(values) || 1
      const y = d3.scaleLinear().domain([0, yMax * 1.1]).nice().range([innerH, 0])

      this.drawAxes(g, x, y, innerH, labels.length)

      const xCenter = d => x(d.label) + x.bandwidth() / 2

      const area = d3.area()
        .x(d => xCenter(d))
        .y0(innerH)
        .y1(d => y(Number(d.value) || 0))
        .curve(d3.curveMonotoneX)

      const line = d3.line()
        .x(d => xCenter(d))
        .y(d => y(Number(d.value) || 0))
        .curve(d3.curveMonotoneX)

      // Gradient fill
      const gradId = `area-grad-${Math.random().toString(36).slice(2, 9)}`
      const grad = svg.append("defs").append("linearGradient")
        .attr("id", gradId).attr("x1", 0).attr("y1", 0).attr("x2", 0).attr("y2", 1)
      grad.append("stop").attr("offset", "0%").attr("stop-color", primaryColor).attr("stop-opacity", 0.35)
      grad.append("stop").attr("offset", "100%").attr("stop-color", primaryColor).attr("stop-opacity", 0.02)

      g.append("path").datum(series).attr("d", area).attr("fill", `url(#${gradId})`)
      g.append("path").datum(series).attr("d", line).attr("fill", "none").attr("stroke", primaryColor).attr("stroke-width", 2)

      g.append("g").selectAll("circle")
        .data(series).join("circle")
        .attr("cx", d => xCenter(d))
        .attr("cy", d => y(Number(d.value) || 0))
        .attr("r", 3)
        .attr("fill", primaryColor)
        .append("title").text(d => `${d.label}: ${this.formatTooltip(d.value)}`)
    }

    if (this.typeValue === "combo") {
      const monthly = series.map(d => Number(d.monthly) || 0)
      const cumulative = series.map(d => Number(d.cumulative) || 0)
      const yLeft = d3.scaleLinear()
        .domain([Math.min(0, d3.min(monthly)), d3.max(monthly) || 1]).nice()
        .range([innerH, 0])
      const yRight = d3.scaleLinear()
        .domain([Math.min(0, d3.min(cumulative)), d3.max(cumulative) || 1]).nice()
        .range([innerH, 0])

      // Left axis
      g.append("g")
        .call(d3.axisLeft(yLeft).ticks(4).tickFormat(v => this.formatValue(v)))
        .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
        .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
        .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))

      // Right axis
      g.append("g")
        .attr("transform", `translate(${innerW},0)`)
        .call(d3.axisRight(yRight).ticks(4).tickFormat(v => this.formatValue(v)))
        .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
        .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
        .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))

      // X axis
      this.drawXAxis(g, x, innerH, labels.length)

      // Zero line on left axis (monthly can be negative)
      if (yLeft.domain()[0] < 0) {
        g.append("line")
          .attr("x1", 0).attr("x2", innerW).attr("y1", yLeft(0)).attr("y2", yLeft(0))
          .attr("stroke", "#cbd5e1").attr("stroke-dasharray", "2,2")
      }

      // Bars (monthly)
      g.append("g")
        .selectAll("rect")
        .data(series)
        .join("rect")
        .attr("x", d => x(d.label))
        .attr("y", d => yLeft(Math.max(0, Number(d.monthly) || 0)))
        .attr("width", x.bandwidth())
        .attr("height", d => Math.abs(yLeft(Number(d.monthly) || 0) - yLeft(0)))
        .attr("fill", d => (Number(d.monthly) || 0) >= 0 ? primaryColor : "#dc2626")
        .attr("opacity", 0.85)
        .attr("rx", 2)
        .append("title")
        .text(d => `${d.label}\nMonthly: ${this.formatTooltip(d.monthly)}\nCumulative: ${this.formatTooltip(d.cumulative)}`)

      // Line (cumulative)
      const xCenter = d => x(d.label) + x.bandwidth() / 2
      const line = d3.line()
        .x(d => xCenter(d))
        .y(d => yRight(Number(d.cumulative) || 0))
        .curve(d3.curveMonotoneX)
      g.append("path").datum(series).attr("d", line).attr("fill", "none").attr("stroke", secondaryColor).attr("stroke-width", 2)
      g.append("g").selectAll("circle")
        .data(series).join("circle")
        .attr("cx", d => xCenter(d))
        .attr("cy", d => yRight(Number(d.cumulative) || 0))
        .attr("r", 3)
        .attr("fill", secondaryColor)
    }
  }

  drawAxes(g, x, y, innerH, labelCount) {
    g.append("g")
      .call(d3.axisLeft(y).ticks(4).tickFormat(v => this.formatValue(v)))
      .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
      .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
      .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))

    this.drawXAxis(g, x, innerH, labelCount)
  }

  drawXAxis(g, x, innerH, labelCount) {
    // Show every other label if there are many to keep readable
    const skip = labelCount > 8 ? 2 : 1
    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).tickValues(x.domain().filter((_, i) => i % skip === 0)))
      .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
      .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
      .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))
  }
}
