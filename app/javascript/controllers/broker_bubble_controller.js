import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    scorecards: Array
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
    const data = this.scorecardsValue.filter(d => d.referrals_365d > 0)
    if (!data.length) {
      this.element.innerHTML = '<div class="dashboard-empty">No broker activity in the last year yet.</div>'
      return
    }

    const width = this.element.clientWidth || 720
    const height = 360
    const margin = { top: 20, right: 24, bottom: 44, left: 56 }
    const innerW = width - margin.left - margin.right
    const innerH = height - margin.top - margin.bottom

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("class", "trend-chart-svg")

    const g = svg.append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const xMax = d3.max(data, d => d.referrals_365d) || 1
    const x = d3.scaleLinear().domain([0, xMax * 1.1]).nice().range([0, innerW])
    const y = d3.scaleLinear().domain([0, 100]).range([innerH, 0])
    const r = d3.scaleSqrt().domain([0, d3.max(data, d => d.commission_earned) || 1]).range([6, 36])

    // Axes
    g.append("g").attr("transform", `translate(0,${innerH})`)
      .call(d3.axisBottom(x).ticks(6))
      .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
      .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
      .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))

    g.append("g")
      .call(d3.axisLeft(y).ticks(5).tickFormat(v => `${v}%`))
      .call(g => g.select(".domain").attr("stroke", "#cbd5e1"))
      .call(g => g.selectAll(".tick text").attr("font-size", 10).attr("fill", "#64748b"))
      .call(g => g.selectAll(".tick line").attr("stroke", "#e2e8f0"))

    // Axis labels
    g.append("text").attr("x", innerW / 2).attr("y", innerH + 36)
      .attr("text-anchor", "middle").attr("font-size", 11).attr("fill", "#475569")
      .text("Applications referred (last 365 days)")
    g.append("text").attr("transform", "rotate(-90)").attr("x", -innerH / 2).attr("y", -42)
      .attr("text-anchor", "middle").attr("font-size", 11).attr("fill", "#475569")
      .text("Approval rate")

    // Quadrant guides at median X and 50% approval
    const xMedian = d3.median(data, d => d.referrals_365d)
    g.append("line").attr("x1", x(xMedian)).attr("x2", x(xMedian))
      .attr("y1", 0).attr("y2", innerH)
      .attr("stroke", "#e2e8f0").attr("stroke-dasharray", "3,3")
    g.append("line").attr("x1", 0).attr("x2", innerW)
      .attr("y1", y(50)).attr("y2", y(50))
      .attr("stroke", "#e2e8f0").attr("stroke-dasharray", "3,3")

    // Quadrant labels
    g.append("text").attr("x", innerW - 4).attr("y", 12)
      .attr("text-anchor", "end").attr("font-size", 10).attr("fill", "#94a3b8")
      .text("⭐ Stars (high volume, high quality)")
    g.append("text").attr("x", 4).attr("y", 12)
      .attr("text-anchor", "start").attr("font-size", 10).attr("fill", "#94a3b8")
      .text("Niche (low volume, high quality)")
    g.append("text").attr("x", innerW - 4).attr("y", innerH - 6)
      .attr("text-anchor", "end").attr("font-size", 10).attr("fill", "#94a3b8")
      .text("Volume but low quality")
    g.append("text").attr("x", 4).attr("y", innerH - 6)
      .attr("text-anchor", "start").attr("font-size", 10).attr("fill", "#94a3b8")
      .text("Underperforming")

    // Bubbles
    const colorFor = d => d.dormant ? "#94a3b8" : "#2563eb"

    const bubble = g.append("g")
      .selectAll("g.broker-bubble")
      .data(data)
      .join("g")
      .attr("class", "broker-bubble")
      .attr("transform", d => `translate(${x(d.referrals_365d)},${y(d.approval_rate)})`)

    bubble.append("circle")
      .attr("r", d => r(d.commission_earned || 0))
      .attr("fill", colorFor)
      .attr("fill-opacity", 0.55)
      .attr("stroke", colorFor)
      .attr("stroke-width", 1.5)
      .append("title")
      .text(d => `${d.broker.name}\nReferred: ${d.referrals_365d}\nApproval: ${d.approval_rate}%\nCommission: ${d3.format("$,.0f")(d.commission_earned)}\nLast referral: ${d.last_referral_at || "—"}`)

    // Label only larger bubbles to avoid clutter
    const labelThreshold = (d3.median(data, d => d.commission_earned) || 0) * 0.5
    bubble.filter(d => (d.commission_earned || 0) > labelThreshold)
      .append("text")
      .attr("text-anchor", "middle")
      .attr("dy", "0.35em")
      .attr("font-size", 10)
      .attr("font-weight", 600)
      .attr("fill", "#0f172a")
      .text(d => d.broker.name.length > 14 ? d.broker.name.slice(0, 13) + "…" : d.broker.name)
  }
}
