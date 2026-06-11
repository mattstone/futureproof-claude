import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    deficitByYear: Array,
    surplusPercentiles: Object,
    holidaysByYear: Array,
    costStructure: Object,
    profitShareMeans: Array,
    applicationsByRegion: Object,
    capitalByRegion: Object
  }

  connect() {
    this.charts = []
    this.loadChartJS()
  }

  disconnect() {
    if (this.initTimer) clearTimeout(this.initTimer)
    this.charts.forEach(c => c.destroy())
  }

  async loadChartJS() {
    console.log("[dashboard-charts] connect, window.Chart=", !!window.Chart)

    // Try importing via importmap (UMD sets window.Chart as side effect)
    try {
      const mod = await import("chart.js")
      console.log("[dashboard-charts] import resolved, mod keys:", Object.keys(mod).slice(0, 5))
      console.log("[dashboard-charts] window.Chart after import:", !!window.Chart)
      // UMD: window.Chart; ESM: mod.Chart or mod.default
      this.ChartJS = window.Chart || mod.Chart || mod.default
    } catch (e) {
      console.warn("[dashboard-charts] import failed:", e.message)
      this.ChartJS = window.Chart
    }

    if (this.ChartJS) {
      console.log("[dashboard-charts] Chart.js ready, rendering charts")
      this.initCharts()
    } else {
      console.warn("[dashboard-charts] Chart.js not available after import")
    }
  }

  initCharts() {

    this.renderDeficitChart()
    this.renderSurplusFanChart()
    this.renderCostDonut()
    this.renderHolidayChart()
    this.renderProfitShareChart()
    this.renderRegionalCharts()
  }

  renderDeficitChart() {
    const ctx = this.element.querySelector("[data-chart=deficit]")
    if (!ctx || !this.deficitByYearValue.length) return

    const data = this.deficitByYearValue
    const labels = data.map((_, i) => `Yr ${i + 1}`)

    const gradient = ctx.getContext("2d").createLinearGradient(0, 0, 0, 300)
    gradient.addColorStop(0, "rgba(239, 68, 68, 0.3)")
    gradient.addColorStop(1, "rgba(239, 68, 68, 0.02)")

    const chart = new this.ChartJS(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [{
          label: "Deficit Probability (%)",
          data,
          borderColor: "#ef4444",
          backgroundColor: gradient,
          fill: true,
          tension: 0.4,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: "#ef4444",
          borderWidth: 2.5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            titleFont: { size: 12, weight: "600" },
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => `PoD: ${item.parsed.y.toFixed(1)}%`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 10 }, maxTicksLimit: 10 }
          },
          y: {
            min: 0,
            max: 60,
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => v + "%"
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderSurplusFanChart() {
    const ctx = this.element.querySelector("[data-chart=surplus-fan]")
    if (!ctx) return

    const percentiles = this.surplusPercentilesValue
    const years = Object.keys(percentiles).map(Number).sort((a, b) => a - b)
    if (!years.length) return

    const labels = years.map(y => `Yr ${y}`)
    const p1 = years.map(y => percentiles[y].p1 / 1000)
    const p10 = years.map(y => percentiles[y].p10 / 1000)
    const median = years.map(y => percentiles[y].median / 1000)
    const p90 = years.map(y => percentiles[y].p90 / 1000)
    const p99 = years.map(y => percentiles[y].p99 / 1000)

    const chart = new this.ChartJS(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "P99",
            data: p99,
            borderColor: "rgba(34, 197, 94, 0.3)",
            backgroundColor: "rgba(34, 197, 94, 0.06)",
            fill: "+1",
            pointRadius: 0,
            borderWidth: 1,
            tension: 0.4
          },
          {
            label: "P90",
            data: p90,
            borderColor: "rgba(34, 197, 94, 0.5)",
            backgroundColor: "rgba(34, 197, 94, 0.1)",
            fill: "+1",
            pointRadius: 0,
            borderWidth: 1,
            tension: 0.4
          },
          {
            label: "Median",
            data: median,
            borderColor: "#3b82f6",
            backgroundColor: "transparent",
            fill: false,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: "#3b82f6",
            borderWidth: 2.5,
            tension: 0.4
          },
          {
            label: "P10",
            data: p10,
            borderColor: "rgba(239, 68, 68, 0.5)",
            backgroundColor: "rgba(239, 68, 68, 0.1)",
            fill: "+1",
            pointRadius: 0,
            borderWidth: 1,
            tension: 0.4
          },
          {
            label: "P1",
            data: p1,
            borderColor: "rgba(239, 68, 68, 0.3)",
            backgroundColor: "transparent",
            fill: false,
            pointRadius: 0,
            borderWidth: 1,
            tension: 0.4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            labels: {
              usePointStyle: true,
              pointStyle: "line",
              font: { size: 10 },
              color: "#64748b",
              padding: 12,
              filter: (item) => ["P99", "P90", "Median", "P10", "P1"].includes(item.text)
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            titleFont: { size: 12, weight: "600" },
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            mode: "index",
            intersect: false,
            callbacks: {
              label: (item) => `${item.dataset.label}: $${item.parsed.y.toFixed(0)}k`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 10 }, maxTicksLimit: 10 }
          },
          y: {
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v.toFixed(0) + "k"
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderCostDonut() {
    const ctx = this.element.querySelector("[data-chart=cost-structure]")
    if (!ctx) return

    const costs = this.costStructureValue
    const labels = Object.keys(costs).map(k => k.replace(/_/g, " ").replace(/\b\w/g, l => l.toUpperCase()))
    const values = Object.values(costs).map(v => (v * 100).toFixed(2))
    const colors = ["#3b82f6", "#8b5cf6", "#06b6d4", "#f59e0b", "#10b981"]

    const chart = new this.ChartJS(ctx, {
      type: "doughnut",
      data: {
        labels,
        datasets: [{
          data: values,
          backgroundColor: colors,
          borderWidth: 0,
          hoverOffset: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "68%",
        plugins: {
          legend: {
            position: "right",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              font: { size: 11 },
              color: "#334155",
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.label}: ${item.parsed}%`
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderHolidayChart() {
    const ctx = this.element.querySelector("[data-chart=holidays]")
    if (!ctx || !this.holidaysByYearValue.length) return

    const data = this.holidaysByYearValue.map(v => (v * 100).toFixed(1))
    const labels = data.map((_, i) => `Yr ${i + 1}`)

    const gradient = ctx.getContext("2d").createLinearGradient(0, 0, 0, 300)
    gradient.addColorStop(0, "rgba(245, 158, 11, 0.25)")
    gradient.addColorStop(1, "rgba(245, 158, 11, 0.02)")

    const chart = new this.ChartJS(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [{
          label: "Holiday Rate (%)",
          data,
          borderColor: "#f59e0b",
          backgroundColor: gradient,
          fill: true,
          tension: 0.4,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: "#f59e0b",
          borderWidth: 2.5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => `Holiday Rate: ${item.parsed.y}%`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 10 }, maxTicksLimit: 10 }
          },
          y: {
            min: 0,
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => v + "%"
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderProfitShareChart() {
    const ctx = this.element.querySelector("[data-chart=profit-share]")
    if (!ctx || !this.profitShareMeansValue.length) return

    const data = this.profitShareMeansValue.map(v => (v / 1000).toFixed(0))
    const labels = this.profitShareMeansValue.map((_, i) => `Year ${(i + 1) * 5}`)

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [{
          label: "Mean Profit Share ($k)",
          data,
          backgroundColor: [
            "rgba(59, 130, 246, 0.7)",
            "rgba(59, 130, 246, 0.75)",
            "rgba(59, 130, 246, 0.8)",
            "rgba(59, 130, 246, 0.85)",
            "rgba(59, 130, 246, 0.9)"
          ],
          borderRadius: 6,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => `Profit Share: $${item.parsed.y}k`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 11 } }
          },
          y: {
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderRegionalCharts() {
    const ctx = this.element.querySelector("[data-chart=regional]")
    if (!ctx) return

    const regions = this.applicationsByRegionValue
    const capital = this.capitalByRegionValue
    if (!Object.keys(regions).length) return

    const labels = Object.keys(regions).map(r => r.toUpperCase())
    const appData = Object.values(regions)
    const capData = Object.values(capital).map(v => v / 1000)

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Applications",
            data: appData,
            backgroundColor: "rgba(59, 130, 246, 0.8)",
            borderRadius: 6,
            borderSkipped: false,
            yAxisID: "y"
          },
          {
            label: "Capital ($k)",
            data: capData,
            backgroundColor: "rgba(16, 185, 129, 0.8)",
            borderRadius: 6,
            borderSkipped: false,
            yAxisID: "y1"
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              font: { size: 11 },
              color: "#64748b",
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#94a3b8", font: { size: 11, weight: "600" } }
          },
          y: {
            position: "left",
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: { color: "#94a3b8", font: { size: 10 } },
            title: { display: true, text: "Applications", color: "#94a3b8", font: { size: 10 } }
          },
          y1: {
            position: "right",
            grid: { drawOnChartArea: false },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            },
            title: { display: true, text: "Capital", color: "#94a3b8", font: { size: 10 } }
          }
        }
      }
    })
    this.charts.push(chart)
  }
}
