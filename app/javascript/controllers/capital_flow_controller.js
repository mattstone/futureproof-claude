import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"
import { sankey, sankeyLinkHorizontal, sankeyJustify } from "d3-sankey"

export default class extends Controller {
  static values = {
    nodes: Array,
    links: Array
  }

  connect() {
    this.render()
    this.resizeHandler = () => this.render()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  colorFor(kind) {
    const palette = {
      funder: "#0ea5e9",
      pool: "#6366f1",
      lender: "#8b5cf6",
      ok: "#16a34a",
      in_holiday: "#f59e0b",
      investment_at_risk: "#dc2626",
      complete: "#64748b",
      awaiting_funding: "#94a3b8",
      awaiting_investment: "#94a3b8"
    }
    return palette[kind] || "#94a3b8"
  }

  formatCurrency(v) {
    return d3.format("$,.0f")(v)
  }

  render() {
    this.element.innerHTML = ""
    const nodes = this.nodesValue.map(n => ({ ...n }))
    const links = this.linksValue.map(l => ({ ...l }))

    if (!nodes.length || !links.length) {
      this.element.innerHTML = '<div class="dashboard-empty">No capital allocation data yet.</div>'
      return
    }

    const width = this.element.clientWidth || 900
    const height = Math.max(360, nodes.length * 18)
    const margin = { top: 12, right: 180, bottom: 12, left: 12 }

    const svg = d3.select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)

    const sankeyGen = sankey()
      .nodeWidth(16)
      .nodePadding(10)
      .nodeAlign(sankeyJustify)
      .extent([[margin.left, margin.top], [width - margin.right, height - margin.bottom]])

    const graph = sankeyGen({ nodes, links })

    svg.append("g")
      .attr("fill", "none")
      .attr("stroke-opacity", 0.35)
      .selectAll("path")
      .data(graph.links)
      .join("path")
      .attr("d", sankeyLinkHorizontal())
      .attr("stroke", d => this.colorFor(d.kind))
      .attr("stroke-width", d => Math.max(1, d.width))
      .append("title")
      .text(d => `${d.source.name} → ${d.target.name}\n${this.formatCurrency(d.value)}`)

    const nodeG = svg.append("g")
      .selectAll("g")
      .data(graph.nodes)
      .join("g")

    nodeG.append("rect")
      .attr("x", d => d.x0)
      .attr("y", d => d.y0)
      .attr("height", d => Math.max(1, d.y1 - d.y0))
      .attr("width", d => d.x1 - d.x0)
      .attr("fill", d => this.colorFor(d.kind))
      .append("title")
      .text(d => `${d.name}\n${this.formatCurrency(d.value)}`)

    nodeG.append("text")
      .attr("x", d => d.x0 < width / 2 ? d.x1 + 6 : d.x0 - 6)
      .attr("y", d => (d.y1 + d.y0) / 2)
      .attr("dy", "0.35em")
      .attr("text-anchor", d => d.x0 < width / 2 ? "start" : "end")
      .attr("font-size", "11px")
      .attr("font-weight", "600")
      .attr("fill", "#0f172a")
      .text(d => d.name)
  }
}
