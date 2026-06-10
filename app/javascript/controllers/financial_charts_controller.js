import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    costStructure: Object,
    profitShareMeans: Array,
    regionalAum: Object,
    regionalContracts: Object,
    poolData: Array,
    meanInvestmentByYear: Object,
    poolUtilisation: Number,
    poolCapacity: Number,
    poolAllocated: Number
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
    try {
      await import("chart.js")
      this.ChartJS = window.Chart
    } catch (e) {
      this.ChartJS = window.Chart
    }

    if (this.ChartJS) {
      this.initCharts()
    } else {
      this.pollForChart(0)
    }
  }

  pollForChart(attempt) {
    if (attempt >= 20) return
    this.initTimer = setTimeout(() => {
      if (window.Chart) {
        this.ChartJS = window.Chart
        this.initCharts()
      } else {
        this.pollForChart(attempt + 1)
      }
    }, 250)
  }

  initCharts() {
    this.renderCostDonut()
    this.renderProfitShareChart()
    this.renderRegionalAumChart()
    this.renderPoolChart()
    this.renderInvestmentGrowthChart()
    this.renderPoolGauge()
  }

  renderCostDonut() {
    const ctx = this.element.querySelector("[data-chart=cost-structure]")
    if (!ctx) return

    const costs = this.costStructureValue
    if (!Object.keys(costs).length) return

    const labels = Object.keys(costs).map(k =>
      k.replace(/_/g, " ").replace(/\b\w/g, l => l.toUpperCase())
    )
    const values = Object.values(costs).map(v => (v * 100).toFixed(2))
    const colors = ["#3b82f6", "#8b5cf6", "#06b6d4", "#f59e0b"]

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
            "rgba(139, 92, 246, 0.6)",
            "rgba(139, 92, 246, 0.7)",
            "rgba(139, 92, 246, 0.75)",
            "rgba(139, 92, 246, 0.8)",
            "rgba(139, 92, 246, 0.9)"
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

  renderRegionalAumChart() {
    const ctx = this.element.querySelector("[data-chart=regional-aum]")
    if (!ctx) return

    const aum = this.regionalAumValue
    const contracts = this.regionalContractsValue
    if (!Object.keys(aum).length) return

    const labels = Object.keys(aum)
    const aumData = Object.values(aum).map(v => v / 1000)
    const contractData = Object.values(contracts)

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "AUM ($k)",
            data: aumData,
            backgroundColor: "rgba(59, 130, 246, 0.8)",
            borderRadius: 6,
            borderSkipped: false,
            yAxisID: "y"
          },
          {
            label: "Contracts",
            data: contractData,
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
            ticks: { color: "#94a3b8", font: { size: 12, weight: "600" } }
          },
          y: {
            position: "left",
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            },
            title: { display: true, text: "AUM", color: "#94a3b8", font: { size: 10 } }
          },
          y1: {
            position: "right",
            grid: { drawOnChartArea: false },
            ticks: { color: "#94a3b8", font: { size: 10 } },
            title: { display: true, text: "Contracts", color: "#94a3b8", font: { size: 10 } }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderPoolChart() {
    const ctx = this.element.querySelector("[data-chart=pool-util]")
    if (!ctx) return

    const pools = this.poolDataValue
    if (!pools.length) return

    const labels = pools.map(p => p.name)
    const allocated = pools.map(p => p.allocated / 1000)
    const remaining = pools.map(p => (p.capacity - p.allocated) / 1000)

    const chart = new this.ChartJS(ctx, {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Allocated ($k)",
            data: allocated,
            backgroundColor: "rgba(59, 130, 246, 0.8)",
            borderRadius: { topLeft: 6, bottomLeft: 6 },
            borderSkipped: false
          },
          {
            label: "Available ($k)",
            data: remaining,
            backgroundColor: "rgba(226, 232, 240, 0.8)",
            borderRadius: { topRight: 6, bottomRight: 6 },
            borderSkipped: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: {
            position: "top",
            labels: {
              usePointStyle: true,
              pointStyle: "circle",
              font: { size: 10 },
              color: "#64748b",
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.dataset.label}: $${item.parsed.x.toFixed(0)}k`
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            grid: { color: "rgba(148, 163, 184, 0.1)" },
            ticks: {
              color: "#94a3b8",
              font: { size: 10 },
              callback: (v) => "$" + v + "k"
            }
          },
          y: {
            stacked: true,
            grid: { display: false },
            ticks: { color: "#334155", font: { size: 11 } }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderInvestmentGrowthChart() {
    const ctx = this.element.querySelector("[data-chart=investment-growth]")
    if (!ctx) return

    const investData = this.meanInvestmentByYearValue
    const years = Object.keys(investData).map(Number).sort((a, b) => a - b)
    if (!years.length) return

    const labels = years.map(y => `Yr ${y}`)
    const values = years.map(y => investData[y] / 1000)

    const gradient = ctx.getContext("2d").createLinearGradient(0, 0, 0, 280)
    gradient.addColorStop(0, "rgba(16, 185, 129, 0.25)")
    gradient.addColorStop(1, "rgba(16, 185, 129, 0.02)")

    const chart = new this.ChartJS(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [{
          label: "Mean Investment ($k)",
          data: values,
          borderColor: "#10b981",
          backgroundColor: gradient,
          fill: true,
          tension: 0.4,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: "#10b981",
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
              label: (item) => `Investment: $${item.parsed.y.toFixed(0)}k`
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

  renderPoolGauge() {
    const ctx = this.element.querySelector("[data-chart=pool-gauge]")
    if (!ctx) return

    const utilisation = this.poolUtilisationValue
    const remaining = Math.max(0, 100 - utilisation)
    const color = utilisation > 80 ? "#ef4444" : utilisation > 50 ? "#f59e0b" : "#10b981"

    const chart = new this.ChartJS(ctx, {
      type: "doughnut",
      data: {
        labels: ["Utilised", "Available"],
        datasets: [{
          data: [utilisation, remaining],
          backgroundColor: [color, "rgba(226, 232, 240, 0.5)"],
          borderWidth: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "75%",
        rotation: -90,
        circumference: 180,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(15, 23, 42, 0.9)",
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
            callbacks: {
              label: (item) => ` ${item.label}: ${item.parsed.toFixed(1)}%`
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }
}
