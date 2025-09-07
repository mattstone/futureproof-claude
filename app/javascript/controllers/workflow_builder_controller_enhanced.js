import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "palette", "properties", "form"]
  static values = { 
    workflowData: String,
    emailTemplates: Array
  }
  
  connect() {
    // Initialize data structures first
    this.nodes = []
    this.connections = []
    this.selectedNode = null
    this.nextNodeId = 1
    this.connectionInProgress = null
    this.draggedNode = null
    
    // SVG for drawing connections
    this.svg = null
    
    // Then initialize the builder
    this.initializeBuilder()
    this.setupDragAndDrop()
    this.createConnectionsSVG()
  }

  initializeBuilder() {
    // Create the visual workflow canvas
    if (this.hasCanvasTarget) {
      this.canvas = this.canvasTarget
      this.canvas.addEventListener('click', this.onCanvasClick.bind(this))
      this.canvas.addEventListener('dragover', this.onDragOver.bind(this))
      this.canvas.addEventListener('drop', this.onDrop.bind(this))
      
      // Initialize with trigger node if editing existing workflow
      if (this.data.get('workflowData')) {
        this.loadExistingWorkflow()
      } else {
        this.addInitialTriggerNode()
      }
    }
  }

  createConnectionsSVG() {
    // Create SVG element for drawing connections
    this.svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    this.svg.classList.add("workflow-connections")
    this.svg.style.position = "absolute"
    this.svg.style.top = "0"
    this.svg.style.left = "0" 
    this.svg.style.width = "100%"
    this.svg.style.height = "100%"
    this.svg.style.pointerEvents = "none"
    this.svg.style.zIndex = "1"
    
    if (this.canvas) {
      this.canvas.appendChild(this.svg)
      this.canvas.style.position = "relative"
    }
  }

  setupDragAndDrop() {
    // Make palette items draggable
    if (this.hasPaletteTarget) {
      const paletteItems = this.paletteTarget.querySelectorAll('.palette-item')
      paletteItems.forEach(item => {
        item.draggable = true
        item.addEventListener('dragstart', this.onDragStart.bind(this))
      })
    }
  }

  onDragStart(event) {
    if (event.target.closest('.workflow-node')) {
      // Moving existing node
      const nodeElement = event.target.closest('.workflow-node')
      const nodeId = parseInt(nodeElement.dataset.nodeId)
      event.dataTransfer.setData('text/plain', `move-node-${nodeId}`)
      event.dataTransfer.effectAllowed = 'move'
      this.draggedNode = this.nodes.find(n => n.id === nodeId)
    } else {
      // Adding new node from palette
      const nodeType = event.target.dataset.nodeType
      event.dataTransfer.setData('text/plain', nodeType)
      event.dataTransfer.effectAllowed = 'copy'
    }
  }

  onDragOver(event) {
    event.preventDefault()
    if (event.dataTransfer.getData('text/plain').startsWith('move-node-')) {
      event.dataTransfer.dropEffect = 'move'
    } else {
      event.dataTransfer.dropEffect = 'copy'
    }
  }

  onDrop(event) {
    event.preventDefault()
    const data = event.dataTransfer.getData('text/plain')
    const rect = this.canvas.getBoundingClientRect()
    const x = event.clientX - rect.left
    const y = event.clientY - rect.top
    
    if (data.startsWith('move-node-')) {
      // Moving existing node
      const nodeId = parseInt(data.replace('move-node-', ''))
      this.moveNode(nodeId, x, y)
    } else {
      // Adding new node from palette
      this.addNode(data, x, y)
    }
    
    this.draggedNode = null
  }

  addInitialTriggerNode() {
    this.addNode('trigger', 100, 100)
  }

  addNode(type, x, y, config = {}) {
    // Convert pixel coordinates to grid positions for better alignment
    const gridSize = 20
    const gridX = Math.round(x / gridSize) * gridSize
    const gridY = Math.round(y / gridSize) * gridSize
    
    const node = {
      id: this.nextNodeId++,
      type: type,
      x: gridX,
      y: gridY,
      config: config,
      connections: []
    }
    
    this.nodes.push(node)
    this.renderNode(node)
    this.updateFormData()
    this.selectNode(node)
  }

  renderNode(node) {
    if (!this.canvas) return
    
    const nodeElement = document.createElement('div')
    nodeElement.className = `workflow-node node-${node.type}`
    nodeElement.dataset.nodeId = node.id
    nodeElement.style.position = 'absolute'
    nodeElement.style.left = `${node.x}px`
    nodeElement.style.top = `${node.y}px`
    nodeElement.style.cursor = 'move'
    nodeElement.style.zIndex = '10'
    
    nodeElement.innerHTML = this.getNodeHTML(node)
    
    // Make nodes draggable for repositioning
    nodeElement.draggable = true
    nodeElement.addEventListener('dragstart', this.onDragStart.bind(this))
    nodeElement.addEventListener('click', (e) => {
      e.stopPropagation()
      this.selectNode(node)
    })
    
    // Add connection points
    this.addConnectionPoints(nodeElement, node)
    
    this.canvas.appendChild(nodeElement)
    
    // Hide canvas hint when first node is added
    this.hideCanvasHint()
    
    // Redraw connections
    this.redrawConnections()
  }

  addConnectionPoints(nodeElement, node) {
    // Add output connection point (right side)
    if (node.type !== 'end') {
      const outputPoint = document.createElement('div')
      outputPoint.className = 'connection-point output-point'
      outputPoint.dataset.nodeId = node.id
      outputPoint.dataset.type = 'output'
      outputPoint.addEventListener('click', (e) => {
        e.stopPropagation()
        this.startConnection(node, 'output')
      })
      nodeElement.appendChild(outputPoint)
    }
    
    // Add input connection point (left side) - not for trigger nodes
    if (node.type !== 'trigger') {
      const inputPoint = document.createElement('div')
      inputPoint.className = 'connection-point input-point'
      inputPoint.dataset.nodeId = node.id
      inputPoint.dataset.type = 'input'
      inputPoint.addEventListener('click', (e) => {
        e.stopPropagation()
        this.completeConnection(node, 'input')
      })
      nodeElement.appendChild(inputPoint)
    }
  }

  startConnection(fromNode, pointType) {
    if (this.connectionInProgress) {
      // Cancel existing connection
      this.cancelConnection()
    }
    
    this.connectionInProgress = {
      from: fromNode,
      fromType: pointType
    }
    
    // Visual feedback
    this.canvas.classList.add('connecting-mode')
    
    // Highlight potential target nodes
    this.nodes.forEach(node => {
      if (node.id !== fromNode.id && node.type !== 'trigger') {
        const nodeEl = this.canvas.querySelector(`[data-node-id="${node.id}"]`)
        if (nodeEl) nodeEl.classList.add('connection-target')
      }
    })
  }

  completeConnection(toNode, pointType) {
    if (!this.connectionInProgress) return
    
    const fromNode = this.connectionInProgress.from
    
    // Don't connect to self or if connection already exists
    if (fromNode.id === toNode.id || this.connectionExists(fromNode.id, toNode.id)) {
      this.cancelConnection()
      return
    }
    
    // Create connection
    const connection = {
      from: fromNode.id,
      to: toNode.id,
      condition: null // For conditional connections
    }
    
    this.connections.push(connection)
    
    // Clear connection mode
    this.cancelConnection()
    
    // Redraw connections
    this.redrawConnections()
    
    // Update form data
    this.updateFormData()
  }

  cancelConnection() {
    this.connectionInProgress = null
    this.canvas.classList.remove('connecting-mode')
    
    // Remove highlighting
    this.canvas.querySelectorAll('.connection-target').forEach(el => {
      el.classList.remove('connection-target')
    })
  }

  connectionExists(fromId, toId) {
    return this.connections.some(conn => conn.from === fromId && conn.to === toId)
  }

  redrawConnections() {
    if (!this.svg) return
    
    // Clear existing connections
    this.svg.innerHTML = ''
    
    // Draw each connection
    this.connections.forEach(connection => {
      this.drawConnection(connection)
    })
  }

  drawConnection(connection) {
    const fromNode = this.nodes.find(n => n.id === connection.from)
    const toNode = this.nodes.find(n => n.id === connection.to)
    
    if (!fromNode || !toNode) return
    
    const fromEl = this.canvas.querySelector(`[data-node-id="${fromNode.id}"]`)
    const toEl = this.canvas.querySelector(`[data-node-id="${toNode.id}"]`)
    
    if (!fromEl || !toEl) return
    
    // Calculate connection points
    const fromRect = fromEl.getBoundingClientRect()
    const toRect = toEl.getBoundingClientRect()
    const canvasRect = this.canvas.getBoundingClientRect()
    
    const fromX = fromNode.x + fromEl.offsetWidth
    const fromY = fromNode.y + fromEl.offsetHeight / 2
    const toX = toNode.x
    const toY = toNode.y + toEl.offsetHeight / 2
    
    // Create curved path
    const controlOffset = Math.min(100, Math.abs(toX - fromX) / 2)
    const controlPoint1X = fromX + controlOffset
    const controlPoint1Y = fromY
    const controlPoint2X = toX - controlOffset
    const controlPoint2Y = toY
    
    // Create SVG path
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    const pathData = `M ${fromX} ${fromY} C ${controlPoint1X} ${controlPoint1Y}, ${controlPoint2X} ${controlPoint2Y}, ${toX} ${toY}`
    
    path.setAttribute("d", pathData)
    path.setAttribute("stroke", "#4f46e5")
    path.setAttribute("stroke-width", "2")
    path.setAttribute("fill", "none")
    path.setAttribute("marker-end", "url(#arrowhead)")
    path.classList.add("workflow-connection")
    
    // Add click handler to delete connection
    path.style.cursor = "pointer"
    path.addEventListener('click', (e) => {
      e.stopPropagation()
      this.deleteConnection(connection)
    })
    
    this.svg.appendChild(path)
    
    // Add arrowhead marker if not exists
    this.ensureArrowheadMarker()
  }

  ensureArrowheadMarker() {
    if (this.svg.querySelector('#arrowhead')) return
    
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs")
    const marker = document.createElementNS("http://www.w3.org/2000/svg", "marker")
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
    
    marker.setAttribute("id", "arrowhead")
    marker.setAttribute("markerWidth", "10")
    marker.setAttribute("markerHeight", "7")
    marker.setAttribute("refX", "9")
    marker.setAttribute("refY", "3.5")
    marker.setAttribute("orient", "auto")
    
    path.setAttribute("d", "M 0 0 L 10 3.5 L 0 7 z")
    path.setAttribute("fill", "#4f46e5")
    
    marker.appendChild(path)
    defs.appendChild(marker)
    this.svg.appendChild(defs)
  }

  deleteConnection(connectionToDelete) {
    this.connections = this.connections.filter(conn => 
      !(conn.from === connectionToDelete.from && conn.to === connectionToDelete.to)
    )
    this.redrawConnections()
    this.updateFormData()
  }

  moveNode(nodeId, newX, newY) {
    const node = this.nodes.find(n => n.id === nodeId)
    if (!node) return
    
    // Grid snap for better alignment
    const gridSize = 20
    node.x = Math.round(newX / gridSize) * gridSize
    node.y = Math.round(newY / gridSize) * gridSize
    
    // Update visual position
    const nodeElement = this.canvas.querySelector(`[data-node-id="${nodeId}"]`)
    if (nodeElement) {
      nodeElement.style.left = `${node.x}px`
      nodeElement.style.top = `${node.y}px`
    }
    
    // Redraw connections
    this.redrawConnections()
    this.updateFormData()
  }

  // Quick action methods for building long chains
  addQuickEmail() {
    const lastNode = this.getLastNode()
    let x = 300, y = 100
    
    if (lastNode) {
      x = lastNode.x + 200
      y = lastNode.y
    }
    
    const emailNode = this.addNode('email', x, y)
    
    // Auto-connect to the last node if possible
    if (lastNode && !this.connectionExists(lastNode.id, emailNode)) {
      this.connections.push({ from: lastNode.id, to: emailNode, condition: null })
      this.redrawConnections()
      this.updateFormData()
    }
  }

  addQuickDelay() {
    const lastNode = this.getLastNode()
    let x = 300, y = 100
    
    if (lastNode) {
      x = lastNode.x + 200
      y = lastNode.y
    }
    
    const delayNode = this.addNode('delay', x, y)
    
    // Auto-connect to the last node if possible
    if (lastNode && !this.connectionExists(lastNode.id, delayNode)) {
      this.connections.push({ from: lastNode.id, to: delayNode, condition: null })
      this.redrawConnections()
      this.updateFormData()
    }
  }

  addQuickCondition() {
    const lastNode = this.getLastNode()
    let x = 300, y = 100
    
    if (lastNode) {
      x = lastNode.x + 200
      y = lastNode.y
    }
    
    const conditionNode = this.addNode('condition', x, y)
    
    // Auto-connect to the last node if possible
    if (lastNode && !this.connectionExists(lastNode.id, conditionNode)) {
      this.connections.push({ from: lastNode.id, to: conditionNode, condition: null })
      this.redrawConnections()
      this.updateFormData()
    }
  }

  getLastNode() {
    // Find the rightmost node (highest x coordinate)
    return this.nodes.reduce((rightmost, node) => {
      if (!rightmost || node.x > rightmost.x) return node
      return rightmost
    }, null)
  }

  // Chain building helper - adds node and automatically connects it
  addToChain(type, config = {}) {
    const lastNode = this.getLastNode()
    let x = 300, y = 100
    
    if (lastNode) {
      x = lastNode.x + 200
      y = lastNode.y
    }
    
    this.addNode(type, x, y, config)
    
    const newNode = this.nodes[this.nodes.length - 1]
    
    // Auto-connect to the last node
    if (lastNode && newNode && !this.connectionExists(lastNode.id, newNode.id)) {
      this.connections.push({ 
        from: lastNode.id, 
        to: newNode.id, 
        condition: null 
      })
      this.redrawConnections()
      this.updateFormData()
    }
    
    return newNode
  }

  getNodeHTML(node) {
    const icons = {
      trigger: 'fas fa-bolt',
      email: 'fas fa-envelope',
      delay: 'fas fa-clock',
      condition: 'fas fa-code-branch',
      update: 'fas fa-edit'
    }
    
    const titles = {
      trigger: 'Trigger',
      email: 'Send Email',
      delay: 'Wait',
      condition: 'Condition',
      update: 'Update Status'
    }
    
    return `
      <div class="node-header">
        <i class="${icons[node.type]}"></i>
        <span class="node-title">${titles[node.type]}</span>
        ${node.type !== 'trigger' ? '<button class="node-delete" data-action="click->workflow-builder#deleteNode">×</button>' : ''}
      </div>
      <div class="node-body">
        <div class="node-summary">${this.getNodeSummary(node)}</div>
      </div>
    `
  }

  getNodeSummary(node) {
    switch(node.type) {
      case 'trigger':
        return 'Workflow starts here'
      case 'email':
        if (node.config.email_template_id) {
          const template = this.emailTemplatesValue.find(t => t.id == node.config.email_template_id)
          return template ? template.name : 'Configure email template'
        }
        return 'Configure email template'
      case 'delay':
        if (node.config.duration && node.config.unit) {
          return `Wait ${node.config.duration} ${node.config.unit}`
        }
        return 'Configure delay'
      case 'condition':
        return 'Configure condition'
      case 'update':
        return 'Configure update'
      default:
        return 'Configure node'
    }
  }

  selectNode(node) {
    // Remove previous selection
    this.canvas.querySelectorAll('.workflow-node.selected').forEach(el => {
      el.classList.remove('selected')
    })
    
    // Select new node
    const nodeElement = this.canvas.querySelector(`[data-node-id="${node.id}"]`)
    if (nodeElement) {
      nodeElement.classList.add('selected')
    }
    
    this.selectedNode = node
    this.showNodeProperties(node)
  }

  deleteNode(event) {
    event.stopPropagation()
    const nodeElement = event.target.closest('.workflow-node')
    const nodeId = parseInt(nodeElement.dataset.nodeId)
    
    // Remove node
    this.nodes = this.nodes.filter(n => n.id !== nodeId)
    
    // Remove connections involving this node
    this.connections = this.connections.filter(conn => 
      conn.from !== nodeId && conn.to !== nodeId
    )
    
    // Remove from DOM
    nodeElement.remove()
    
    // Redraw connections
    this.redrawConnections()
    
    // Update form
    this.updateFormData()
    
    // Clear properties if this node was selected
    if (this.selectedNode && this.selectedNode.id === nodeId) {
      this.selectedNode = null
      this.hideNodeProperties()
    }
  }

  onCanvasClick(event) {
    // Deselect nodes when clicking empty canvas
    if (event.target === this.canvas) {
      this.canvas.querySelectorAll('.workflow-node.selected').forEach(el => {
        el.classList.remove('selected')
      })
      this.selectedNode = null
      this.hideNodeProperties()
      this.cancelConnection()
    }
  }

  hideCanvasHint() {
    const hint = this.canvas.querySelector('.canvas-hint')
    if (hint) hint.style.display = 'none'
  }

  showNodeProperties(node) {
    // Implementation for showing node configuration properties
    // This would show a properties panel for the selected node
    if (this.hasPropertiesTarget) {
      this.propertiesTarget.innerHTML = this.getPropertiesHTML(node)
      this.propertiesTarget.style.display = 'block'
    }
  }

  hideNodeProperties() {
    if (this.hasPropertiesTarget) {
      this.propertiesTarget.style.display = 'none'
    }
  }

  getPropertiesHTML(node) {
    // Generate configuration form for the node
    return `
      <div class="node-properties">
        <h4>${node.type.charAt(0).toUpperCase() + node.type.slice(1)} Configuration</h4>
        <div class="properties-form">
          ${this.getNodeConfigForm(node)}
        </div>
      </div>
    `
  }

  getNodeConfigForm(node) {
    // Return appropriate configuration form based on node type
    switch(node.type) {
      case 'email':
        return this.getEmailNodeForm(node)
      case 'delay':
        return this.getDelayNodeForm(node)
      case 'condition':
        return this.getConditionNodeForm(node)
      default:
        return '<p>No configuration needed</p>'
    }
  }

  updateFormData() {
    // Update the hidden form field with workflow data
    const workflowData = {
      nodes: this.nodes.map(node => ({
        id: `node_${node.id}`,
        type: node.type,
        config: node.config,
        position: { x: node.x, y: node.y }
      })),
      connections: this.connections.map(conn => ({
        from: `node_${conn.from}`,
        to: `node_${conn.to}`,
        condition: conn.condition
      }))
    }
    
    const hiddenField = this.element.querySelector('input[name="email_workflow[workflow_builder_data]"]')
    if (hiddenField) {
      hiddenField.value = JSON.stringify(workflowData)
    }
  }

  loadExistingWorkflow() {
    // Load existing workflow data
    const workflowData = this.data.get('workflowData')
    if (workflowData) {
      try {
        const data = JSON.parse(workflowData)
        
        // Load nodes
        if (data.nodes) {
          data.nodes.forEach(nodeData => {
            const node = {
              id: parseInt(nodeData.id.replace('node_', '')),
              type: nodeData.type,
              x: nodeData.position?.x || 100,
              y: nodeData.position?.y || 100,
              config: nodeData.config || {}
            }
            
            this.nodes.push(node)
            this.renderNode(node)
            
            // Update nextNodeId
            if (node.id >= this.nextNodeId) {
              this.nextNodeId = node.id + 1
            }
          })
        }
        
        // Load connections
        if (data.connections) {
          this.connections = data.connections.map(conn => ({
            from: parseInt(conn.from.replace('node_', '')),
            to: parseInt(conn.to.replace('node_', '')),
            condition: conn.condition
          }))
          this.redrawConnections()
        }
        
        // If no nodes, add initial trigger
        if (this.nodes.length === 0) {
          this.addInitialTriggerNode()
        }
        
      } catch (error) {
        console.error('Error loading workflow data:', error)
        this.addInitialTriggerNode()
      }
    } else {
      this.addInitialTriggerNode()
    }
  }
}