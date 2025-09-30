import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    data: Array,
    type: String,
    max: Number
  }

  connect() {
    this.renderChart()

    // Re-render on window resize
    this.resizeObserver = new ResizeObserver(() => {
      this.renderChart()
    })
    this.resizeObserver.observe(this.element)
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
  }

  renderChart() {
    // Clear existing chart
    d3.select(this.element).selectAll("*").remove()

    if (!this.hasDataValue || this.dataValue.length === 0) {
      this.renderEmptyState()
      return
    }

    const type = this.hasTypeValue ? this.typeValue : 'bar'

    if (type === 'bar') {
      this.renderBarChart()
    } else if (type === 'area') {
      this.renderAreaChart()
    }
  }

  renderBarChart() {
    const data = this.dataValue
    const margin = { top: 40, right: 20, bottom: 60, left: 60 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = 320 - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Add gradient definitions
    const defs = svg.append("defs")

    const gradient = defs.append("linearGradient")
      .attr("id", "barGradient")
      .attr("x1", "0%")
      .attr("y1", "100%")
      .attr("x2", "0%")
      .attr("y2", "0%")

    gradient.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "#0891b2")
      .attr("stop-opacity", 1)

    gradient.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "#06b6d4")
      .attr("stop-opacity", 1)

    // Add glow filter
    const filter = defs.append("filter")
      .attr("id", "glow")

    filter.append("feGaussianBlur")
      .attr("stdDeviation", "3")
      .attr("result", "coloredBlur")

    const feMerge = filter.append("feMerge")
    feMerge.append("feMergeNode").attr("in", "coloredBlur")
    feMerge.append("feMergeNode").attr("in", "SourceGraphic")

    // Scales
    const x = d3.scaleBand()
      .domain(data.map(d => d.label))
      .range([0, width])
      .padding(0.3)

    const maxValue = this.hasMaxValue ? this.maxValue : d3.max(data, d => d.value)
    const y = d3.scaleLinear()
      .domain([0, maxValue * 1.1])
      .range([height, 0])

    // Grid lines
    svg.append("g")
      .attr("class", "grid")
      .attr("opacity", 0.1)
      .call(d3.axisLeft(y)
        .tickSize(-width)
        .tickFormat("")
      )

    // X Axis
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x))
      .selectAll("text")
      .style("text-anchor", "end")
      .style("font-size", "12px")
      .style("font-weight", "500")
      .style("fill", "#64748b")
      .attr("dx", "-.8em")
      .attr("dy", ".15em")
      .attr("transform", "rotate(-35)")

    // Y Axis
    svg.append("g")
      .call(d3.axisLeft(y)
        .ticks(5)
        .tickFormat(d => this.formatCurrency(d))
      )
      .selectAll("text")
      .style("font-size", "12px")
      .style("font-weight", "500")
      .style("fill", "#64748b")

    // Remove axis lines
    svg.selectAll(".domain").remove()
    svg.selectAll(".tick line").remove()

    // Bars
    const bars = svg.selectAll(".bar")
      .data(data)
      .enter()
      .append("g")
      .attr("class", "bar-group")

    bars.append("rect")
      .attr("class", "bar")
      .attr("x", d => x(d.label))
      .attr("width", x.bandwidth())
      .attr("y", height)
      .attr("height", 0)
      .attr("rx", 8)
      .attr("ry", 8)
      .attr("fill", "url(#barGradient)")
      .style("filter", "url(#glow)")
      .style("cursor", "pointer")
      .on("mouseenter", function(event, d) {
        d3.select(this)
          .transition()
          .duration(200)
          .attr("opacity", 0.8)
          .attr("transform", "translate(0, -4)")
      })
      .on("mouseleave", function(event, d) {
        d3.select(this)
          .transition()
          .duration(200)
          .attr("opacity", 1)
          .attr("transform", "translate(0, 0)")
      })
      .transition()
      .duration(800)
      .delay((d, i) => i * 100)
      .ease(d3.easeCubicOut)
      .attr("y", d => y(d.value))
      .attr("height", d => height - y(d.value))

    // Value labels
    bars.append("text")
      .attr("class", "value-label")
      .attr("x", d => x(d.label) + x.bandwidth() / 2)
      .attr("y", height)
      .attr("text-anchor", "middle")
      .style("font-size", "12px")
      .style("font-weight", "700")
      .style("fill", "#0f172a")
      .style("opacity", 0)
      .text(d => this.formatCurrency(d.value))
      .transition()
      .duration(800)
      .delay((d, i) => i * 100 + 400)
      .attr("y", d => y(d.value) - 8)
      .style("opacity", 1)
  }

  renderAreaChart() {
    const data = this.dataValue
    const margin = { top: 40, right: 20, bottom: 60, left: 60 }
    const width = this.element.clientWidth - margin.left - margin.right
    const height = 320 - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Add gradient definitions
    const defs = svg.append("defs")

    const areaGradient = defs.append("linearGradient")
      .attr("id", "areaGradient")
      .attr("x1", "0%")
      .attr("y1", "100%")
      .attr("x2", "0%")
      .attr("y2", "0%")

    areaGradient.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "#0891b2")
      .attr("stop-opacity", 0.1)

    areaGradient.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "#06b6d4")
      .attr("stop-opacity", 0.4)

    // Scales
    const x = d3.scaleBand()
      .domain(data.map(d => d.label))
      .range([0, width])
      .padding(0.1)

    const maxValue = this.hasMaxValue ? this.maxValue : d3.max(data, d => d.value)
    const y = d3.scaleLinear()
      .domain([0, maxValue * 1.1])
      .range([height, 0])

    // Grid lines
    svg.append("g")
      .attr("class", "grid")
      .attr("opacity", 0.1)
      .call(d3.axisLeft(y)
        .tickSize(-width)
        .tickFormat("")
      )

    // X Axis
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x))
      .selectAll("text")
      .style("text-anchor", "end")
      .style("font-size", "12px")
      .style("font-weight", "500")
      .style("fill", "#64748b")
      .attr("dx", "-.8em")
      .attr("dy", ".15em")
      .attr("transform", "rotate(-35)")

    // Y Axis
    svg.append("g")
      .call(d3.axisLeft(y)
        .ticks(5)
        .tickFormat(d => this.formatCurrency(d))
      )
      .selectAll("text")
      .style("font-size", "12px")
      .style("font-weight", "500")
      .style("fill", "#64748b")

    // Remove axis lines
    svg.selectAll(".domain").remove()
    svg.selectAll(".tick line").remove()

    // Create area generator
    const area = d3.area()
      .x((d, i) => x(d.label) + x.bandwidth() / 2)
      .y0(height)
      .y1(d => y(d.value))
      .curve(d3.curveMonotoneX)

    // Create line generator
    const line = d3.line()
      .x((d, i) => x(d.label) + x.bandwidth() / 2)
      .y(d => y(d.value))
      .curve(d3.curveMonotoneX)

    // Add area
    const areaPath = svg.append("path")
      .datum(data)
      .attr("class", "area")
      .attr("fill", "url(#areaGradient)")
      .attr("d", area)
      .style("opacity", 0)
      .transition()
      .duration(1000)
      .style("opacity", 1)

    // Add line
    const linePath = svg.append("path")
      .datum(data)
      .attr("class", "line")
      .attr("fill", "none")
      .attr("stroke", "#0891b2")
      .attr("stroke-width", 3)
      .attr("d", line)
      .attr("stroke-dasharray", function() {
        return this.getTotalLength()
      })
      .attr("stroke-dashoffset", function() {
        return this.getTotalLength()
      })
      .transition()
      .duration(1500)
      .ease(d3.easeCubicOut)
      .attr("stroke-dashoffset", 0)

    // Add dots
    svg.selectAll(".dot")
      .data(data)
      .enter()
      .append("circle")
      .attr("class", "dot")
      .attr("cx", d => x(d.label) + x.bandwidth() / 2)
      .attr("cy", d => y(d.value))
      .attr("r", 0)
      .attr("fill", "#06b6d4")
      .attr("stroke", "#ffffff")
      .attr("stroke-width", 3)
      .style("cursor", "pointer")
      .on("mouseenter", function(event, d) {
        d3.select(this)
          .transition()
          .duration(200)
          .attr("r", 8)

        // Show tooltip
        const tooltip = d3.select("body").append("div")
          .attr("class", "chart-tooltip")
          .style("position", "absolute")
          .style("background", "rgba(15, 23, 42, 0.95)")
          .style("color", "white")
          .style("padding", "12px 16px")
          .style("border-radius", "8px")
          .style("font-size", "14px")
          .style("font-weight", "600")
          .style("pointer-events", "none")
          .style("box-shadow", "0 4px 12px rgba(0, 0, 0, 0.3)")
          .style("z-index", "9999")
          .html(`<div>${d.label}</div><div style="color: #06b6d4; font-size: 16px; margin-top: 4px;">${this.formatCurrency(d.value)}</div>`)
          .style("left", (event.pageX + 10) + "px")
          .style("top", (event.pageY - 10) + "px")
          .style("opacity", 0)
          .transition()
          .duration(200)
          .style("opacity", 1)
      }.bind(this))
      .on("mouseleave", function(event, d) {
        d3.select(this)
          .transition()
          .duration(200)
          .attr("r", 5)

        d3.selectAll(".chart-tooltip").remove()
      })
      .transition()
      .duration(600)
      .delay((d, i) => i * 80 + 1000)
      .attr("r", 5)

    // Value labels
    svg.selectAll(".value-label")
      .data(data)
      .enter()
      .append("text")
      .attr("class", "value-label")
      .attr("x", d => x(d.label) + x.bandwidth() / 2)
      .attr("y", height)
      .attr("text-anchor", "middle")
      .style("font-size", "12px")
      .style("font-weight", "700")
      .style("fill", "#0f172a")
      .style("opacity", 0)
      .text(d => this.formatCurrency(d.value))
      .transition()
      .duration(600)
      .delay((d, i) => i * 80 + 1200)
      .attr("y", d => y(d.value) - 15)
      .style("opacity", 1)
  }

  renderEmptyState() {
    const div = d3.select(this.element)
      .append("div")
      .style("text-align", "center")
      .style("padding", "60px 20px")
      .style("color", "#94a3b8")
      .style("font-size", "14px")

    div.append("div")
      .style("font-size", "48px")
      .style("margin-bottom", "16px")
      .text("📊")

    div.append("div")
      .style("font-weight", "600")
      .style("margin-bottom", "8px")
      .text("No data available")

    div.append("div")
      .text("Data will appear here once contracts are created")
  }

  formatCurrency(value) {
    if (value >= 1000000) {
      return `$${(value / 1000000).toFixed(1)}M`
    } else if (value >= 1000) {
      return `$${(value / 1000).toFixed(0)}K`
    } else {
      return `$${value.toFixed(0)}`
    }
  }
}