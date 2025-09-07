import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "palette", "properties", "form"]
  static values = { 
    workflowData: String,
    emailTemplates: Array
  }

  connect() {
    console.log("Enhanced Workflow Builder connected")
    this.nodes = []
    this.connections = []
    this.selectedNode = null
    this.canvasRect = null
    this.draggedElement = null
    this.isDraggingNode = false
    this.dragOffset = { x: 0, y: 0 }
    this.gridSize = 20
    this.connectingFrom = null
    this.nextNodeId = 1
    
    this.initCanvas()
    this.initPalette()
    this.loadExistingWorkflow()
    this.createSVGLayer()
  }

  initCanvas() {
    this.canvasRect = this.canvasTarget.getBoundingClientRect()
    this.canvasTarget.addEventListener('dragover', this.handleCanvasDragOver.bind(this))
    this.canvasTarget.addEventListener('drop', this.handleCanvasDrop.bind(this))
    this.canvasTarget.addEventListener('click', this.handleCanvasClick.bind(this))
    this.canvasTarget.addEventListener('mousedown', this.handleMouseDown.bind(this))
    this.canvasTarget.addEventListener('mousemove', this.handleMouseMove.bind(this))
    this.canvasTarget.addEventListener('mouseup', this.handleMouseUp.bind(this))
    
    // Make canvas relative positioned for absolute positioning of nodes
    this.canvasTarget.style.position = 'relative'
  }

  initPalette() {
    const paletteItems = this.paletteTarget.querySelectorAll('.palette-item')
    paletteItems.forEach(item => {
      item.draggable = true
      item.addEventListener('dragstart', this.handlePaletteDragStart.bind(this))
    })
  }

  createSVGLayer() {
    // Create SVG layer for connections
    this.svgLayer = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    this.svgLayer.style.position = 'absolute'
    this.svgLayer.style.top = '0'
    this.svgLayer.style.left = '0'
    this.svgLayer.style.width = '100%'
    this.svgLayer.style.height = '100%'
    this.svgLayer.style.pointerEvents = 'none'
    this.svgLayer.style.zIndex = '1'
    this.canvasTarget.appendChild(this.svgLayer)

    // Add arrowhead marker
    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs')
    const marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker')
    marker.setAttribute('id', 'arrowhead')
    marker.setAttribute('markerWidth', '10')
    marker.setAttribute('markerHeight', '7')
    marker.setAttribute('refX', '9')
    marker.setAttribute('refY', '3.5')
    marker.setAttribute('orient', 'auto')
    
    const polygon = document.createElementNS('http://www.w3.org/2000/svg', 'polygon')
    polygon.setAttribute('points', '0 0, 10 3.5, 0 7')
    polygon.setAttribute('fill', '#6366f1')
    
    marker.appendChild(polygon)
    defs.appendChild(marker)
    this.svgLayer.appendChild(defs)
  }

  handlePaletteDragStart(event) {
    this.draggedElement = {
      type: event.target.dataset.nodeType,
      element: event.target
    }
    event.dataTransfer.effectAllowed = 'copy'
  }

  handleCanvasDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'copy'
  }

  handleCanvasDrop(event) {
    event.preventDefault()
    if (!this.draggedElement) return

    const rect = this.canvasTarget.getBoundingClientRect()
    const x = this.snapToGrid(event.clientX - rect.left)
    const y = this.snapToGrid(event.clientY - rect.top)

    this.createNode(this.draggedElement.type, x, y)
    this.draggedElement = null
  }

  handleMouseDown(event) {
    const nodeElement = event.target.closest('.workflow-node')
    if (nodeElement && !event.target.closest('.node-delete, .connection-point')) {
      this.isDraggingNode = true
      this.draggedNodeId = nodeElement.dataset.nodeId
      
      const rect = this.canvasTarget.getBoundingClientRect()
      const nodeRect = nodeElement.getBoundingClientRect()
      this.dragOffset = {
        x: event.clientX - nodeRect.left,
        y: event.clientY - nodeRect.top
      }
      
      nodeElement.style.zIndex = '1000'
      event.preventDefault()
    }

    // Handle connection point clicks
    const connectionPoint = event.target.closest('.connection-point')
    if (connectionPoint) {
      const nodeElement = connectionPoint.closest('.workflow-node')
      const nodeId = nodeElement.dataset.nodeId
      const isOutput = connectionPoint.classList.contains('output-point')
      
      this.handleConnectionPoint(nodeId, isOutput, event)
      event.stopPropagation()
    }
  }

  handleMouseMove(event) {
    if (this.isDraggingNode && this.draggedNodeId) {
      const rect = this.canvasTarget.getBoundingClientRect()
      const x = this.snapToGrid(event.clientX - rect.left - this.dragOffset.x)
      const y = this.snapToGrid(event.clientY - rect.top - this.dragOffset.y)
      
      // Update node position
      const nodeElement = document.querySelector(`[data-node-id="${this.draggedNodeId}"]`)
      if (nodeElement) {
        nodeElement.style.left = `${x}px`
        nodeElement.style.top = `${y}px`
        
        // Update node data
        const node = this.nodes.find(n => n.id == this.draggedNodeId)
        if (node) {
          node.x = x
          node.y = y
          node.gridX = Math.floor(x / this.gridSize)
          node.gridY = Math.floor(y / this.gridSize)
        }
        
        // Redraw connections
        this.redrawConnections()
      }
    }
  }

  handleMouseUp(event) {
    if (this.isDraggingNode) {
      const nodeElement = document.querySelector(`[data-node-id="${this.draggedNodeId}"]`)
      if (nodeElement) {
        nodeElement.style.zIndex = '10'
      }
      this.isDraggingNode = false
      this.draggedNodeId = null
      this.updateFormData()
    }
  }

  handleConnectionPoint(nodeId, isOutput, event) {
    if (this.connectingFrom === null) {
      // Start connecting
      if (isOutput) {
        this.connectingFrom = nodeId
        this.showConnectionFeedback(nodeId, true)
      }
    } else {
      // Complete connection
      if (!isOutput && this.connectingFrom != nodeId) {
        this.createConnection(this.connectingFrom, nodeId)
      }
      this.clearConnectionFeedback()
      this.connectingFrom = null
    }
  }

  showConnectionFeedback(nodeId, connecting) {
    const nodeElement = document.querySelector(`[data-node-id="${nodeId}"]`)
    if (nodeElement) {
      if (connecting) {
        nodeElement.classList.add('connecting-from')
        // Highlight valid targets
        this.nodes.forEach(node => {
          if (node.id != nodeId) {
            const targetElement = document.querySelector(`[data-node-id="${node.id}"]`)
            targetElement?.classList.add('connection-target')
          }
        })
      } else {
        nodeElement.classList.remove('connecting-from', 'connection-target')
      }
    }
  }

  clearConnectionFeedback() {
    document.querySelectorAll('.workflow-node').forEach(node => {
      node.classList.remove('connecting-from', 'connection-target')
    })
  }

  snapToGrid(value) {
    return Math.round(value / this.gridSize) * this.gridSize
  }

  createNode(type, x, y) {
    const nodeId = this.nextNodeId++
    
    // Auto-position if coordinates would overlap
    const adjustedPosition = this.findAvailablePosition(x, y)
    
    const node = {
      id: nodeId,
      type: type,
      x: adjustedPosition.x,
      y: adjustedPosition.y,
      gridX: Math.floor(adjustedPosition.x / this.gridSize),
      gridY: Math.floor(adjustedPosition.y / this.gridSize),
      config: this.getDefaultNodeConfig(type),
      connections: []
    }
    
    this.nodes.push(node)
    this.renderNode(node)
    
    // Auto-connect to previous node if building a chain
    this.autoConnectToChain(node)
    
    this.updateFormData()
    this.hideCanvasHint()
    return node
  }

  findAvailablePosition(x, y) {
    const nodeWidth = 200
    const nodeHeight = 100
    const margin = 20
    
    let testX = x
    let testY = y
    let attempts = 0
    
    while (attempts < 50) {
      const hasOverlap = this.nodes.some(node => {
        return Math.abs(node.x - testX) < nodeWidth + margin &&
               Math.abs(node.y - testY) < nodeHeight + margin
      })
      
      if (!hasOverlap) {
        return { x: testX, y: testY }
      }
      
      // Try next position in a spiral pattern
      if (attempts % 2 === 0) {
        testX += nodeWidth + margin
      } else {
        testY += nodeHeight + margin
        testX = x // Reset X for next row
      }
      
      attempts++
    }
    
    return { x: testX, y: testY }
  }

  autoConnectToChain(newNode) {
    if (this.nodes.length <= 1) return
    
    // Find the last node that doesn't have outgoing connections
    const unconnectedNodes = this.nodes.filter(node => {
      return node.id != newNode.id && 
             !this.connections.some(conn => conn.from == node.id)
    })
    
    if (unconnectedNodes.length > 0) {
      const lastNode = unconnectedNodes[unconnectedNodes.length - 1]
      this.createConnection(lastNode.id, newNode.id)
    }
  }

  createConnection(fromNodeId, toNodeId) {
    // Prevent duplicate connections
    const existingConnection = this.connections.find(conn => 
      conn.from == fromNodeId && conn.to == toNodeId
    )
    if (existingConnection) return

    const connection = {
      id: `conn_${Date.now()}`,
      from: fromNodeId,
      to: toNodeId
    }
    
    this.connections.push(connection)
    this.drawConnection(connection)
    this.updateFormData()
  }

  drawConnection(connection) {
    const fromNode = this.nodes.find(n => n.id == connection.from)
    const toNode = this.nodes.find(n => n.id == connection.to)
    
    if (!fromNode || !toNode) return

    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('class', 'connection-path')
    path.setAttribute('data-connection-id', connection.id)
    path.setAttribute('stroke', '#6366f1')
    path.setAttribute('stroke-width', '2')
    path.setAttribute('fill', 'none')
    path.setAttribute('marker-end', 'url(#arrowhead)')
    
    this.updateConnectionPath(path, fromNode, toNode)
    this.svgLayer.appendChild(path)
    
    // Add click handler for connection deletion
    path.style.pointerEvents = 'stroke'
    path.style.cursor = 'pointer'
    path.addEventListener('dblclick', () => this.deleteConnection(connection.id))
  }

  updateConnectionPath(path, fromNode, toNode) {
    const nodeWidth = 200
    const nodeHeight = 80
    
    const startX = fromNode.x + nodeWidth
    const startY = fromNode.y + nodeHeight / 2
    const endX = toNode.x
    const endY = toNode.y + nodeHeight / 2
    
    // Create curved path
    const midX = startX + (endX - startX) / 2
    const pathData = `M ${startX} ${startY} C ${midX} ${startY}, ${midX} ${endY}, ${endX} ${endY}`
    
    path.setAttribute('d', pathData)
  }

  redrawConnections() {
    this.connections.forEach(connection => {
      const pathElement = this.svgLayer.querySelector(`[data-connection-id="${connection.id}"]`)
      const fromNode = this.nodes.find(n => n.id == connection.from)
      const toNode = this.nodes.find(n => n.id == connection.to)
      
      if (pathElement && fromNode && toNode) {
        this.updateConnectionPath(pathElement, fromNode, toNode)
      }
    })
  }

  deleteConnection(connectionId) {
    this.connections = this.connections.filter(conn => conn.id !== connectionId)
    const pathElement = this.svgLayer.querySelector(`[data-connection-id="${connectionId}"]`)
    if (pathElement) {
      pathElement.remove()
    }
    this.updateFormData()
  }

  getDefaultNodeConfig(type) {
    switch(type) {
      case 'trigger':
        return { trigger_type: '' }
      case 'email':
        return { email_template_id: '' }
      case 'delay':
        return { duration: 1, unit: 'hours' }
      case 'condition':
        return { condition_type: '' }
      case 'update':
        return { field: '', value: '' }
      default:
        return {}
    }
  }

  renderNode(node) {
    const nodeElement = document.createElement('div')
    nodeElement.className = `workflow-node node-${node.type}`
    nodeElement.dataset.nodeId = node.id
    nodeElement.style.position = 'absolute'
    nodeElement.style.left = `${node.x}px`
    nodeElement.style.top = `${node.y}px`
    nodeElement.style.zIndex = '10'
    
    nodeElement.innerHTML = `
      <div class="node-header">
        <div class="node-icon">
          ${this.getNodeIcon(node.type)}
        </div>
        <span class="node-title">${this.getNodeTitle(node.type)}</span>
        ${node.type !== 'trigger' ? `<button class="node-delete" data-action="click->workflow-builder#deleteNode" data-node-id="${node.id}"><i class="fas fa-times"></i></button>` : ''}
      </div>
      <div class="node-body">
        <div class="node-description">
          ${this.getNodeDescription(node)}
        </div>
      </div>
      <div class="connection-points">
        <div class="input-point connection-point" title="Input: click to receive connections"></div>
        <div class="output-point connection-point" title="Output: click to connect to other nodes"></div>
      </div>
    `

    // Add click handler for node selection
    nodeElement.addEventListener('click', (e) => {
      e.stopPropagation()
      this.selectNode(node)
    })

    this.canvasTarget.appendChild(nodeElement)
  }

  getNodeIcon(type) {
    const icons = {
      trigger: '<i class="fas fa-bolt"></i>',
      email: '<i class="fas fa-envelope"></i>',
      delay: '<i class="fas fa-clock"></i>',
      condition: '<i class="fas fa-code-branch"></i>',
      update: '<i class="fas fa-edit"></i>'
    }
    return icons[type] || '<i class="fas fa-circle"></i>'
  }

  getNodeTitle(type) {
    const titles = {
      trigger: 'Trigger',
      email: 'Send Email',
      delay: 'Wait',
      condition: 'Condition',
      update: 'Update Status'
    }
    return titles[type] || 'Node'
  }

  getNodeDescription(node) {
    switch(node.type) {
      case 'trigger':
        if (node.config.trigger_type === 'application_status_changed') {
          if (node.config.from_status && node.config.to_status) {
            const statuses = this.getApplicationStatuses()
            const fromLabel = statuses.find(s => s.key === node.config.from_status)?.label
            const toLabel = statuses.find(s => s.key === node.config.to_status)?.label
            return `App: ${fromLabel} → ${toLabel}`
          } else {
            return 'Configure app status change'
          }
        }
        if (node.config.trigger_type === 'contract_status_changed') {
          if (node.config.contract_from_status && node.config.contract_to_status) {
            const statuses = this.getContractStatuses()
            const fromLabel = statuses.find(s => s.key === node.config.contract_from_status)?.label
            const toLabel = statuses.find(s => s.key === node.config.contract_to_status)?.label
            return `Contract: ${fromLabel} → ${toLabel}`
          } else {
            return 'Configure contract status change'
          }
        }
        return node.config.trigger_type ? node.config.trigger_type.replace('_', ' ').toUpperCase() : 'Select trigger type'
      case 'email':
        if (node.config.email_template_id) {
          const template = this.emailTemplatesValue?.find(t => t.id == node.config.email_template_id)
          return template ? `Send: ${template.name}` : 'Configure email template'
        }
        return 'Configure email template'
      case 'delay':
        return node.config.duration ? `Wait ${node.config.duration} ${node.config.unit || 'minutes'}` : 'Configure delay'
      case 'condition':
        return node.config.condition_type ? 'Check condition' : 'Configure condition'
      case 'update':
        return node.config.field ? `Update ${node.config.field}` : 'Configure update'
      default:
        return 'Configure node'
    }
  }

  selectNode(node) {
    // Clear previous selection
    document.querySelectorAll('.workflow-node').forEach(n => n.classList.remove('selected'))

    this.selectedNode = node
    
    if (this.selectedNode) {
      const nodeElement = document.querySelector(`[data-node-id="${node.id}"]`)
      nodeElement.classList.add('selected')
      this.showNodeProperties(this.selectedNode)
    }
  }

  showNodeProperties(node) {
    const propertiesContent = this.propertiesTarget.querySelector('.panel-content')
    propertiesContent.innerHTML = this.renderNodeProperties(node)
    this.propertiesTarget.classList.add('visible')
  }

  renderNodeProperties(node) {
    switch(node.type) {
      case 'trigger':
        return this.getTriggerPropertiesHTML(node)
      case 'email':
        return this.getEmailPropertiesHTML(node)
      case 'delay':
        return this.getDelayPropertiesHTML(node)
      case 'condition':
        return this.getConditionPropertiesHTML(node)
      case 'update':
        return this.getUpdatePropertiesHTML(node)
      default:
        return '<p>Select a node to configure its properties</p>'
    }
  }

  getTriggerPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Trigger Configuration</h3>
      <div class="property-group">
        <label>Trigger Type</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="trigger_type">
          <option value="">Select trigger type...</option>
          <option value="application_created" ${node.config.trigger_type === 'application_created' ? 'selected' : ''}>Application Created</option>
          <option value="application_status_changed" ${node.config.trigger_type === 'application_status_changed' ? 'selected' : ''}>Application Status Changed</option>
          <option value="user_registered" ${node.config.trigger_type === 'user_registered' ? 'selected' : ''}>User Registered</option>
          <option value="document_uploaded" ${node.config.trigger_type === 'document_uploaded' ? 'selected' : ''}>Document Uploaded</option>
        </select>
      </div>
      ${this.getTriggerConditionsHTML(node)}
      
      <div class="connection-info">
        <h6>Connections</h6>
        <p class="text-small">
          <strong>Output:</strong> Click the right circle to connect to other nodes
        </p>
      </div>
    `
  }

  getTriggerConditionsHTML(node) {
    if (!node.config.trigger_type) return ''
    
    switch(node.config.trigger_type) {
      case 'application_status_changed':
        return this.getApplicationStatusChangeHTML(node)
      default:
        return '<p class="note">This trigger type doesn\'t require additional configuration.</p>'
    }
  }

  getEmailPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Email Configuration</h3>
      <div class="property-group">
        <label>Email Template</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="email_template_id">
          <option value="">Select template...</option>
          ${this.getEmailTemplateOptions(node.config.email_template_id)}
        </select>
        <p class="field-help">Choose which email template to send</p>
      </div>
      
      <div class="connection-info">
        <h6>Connections</h6>
        <p class="text-small">
          <strong>Input:</strong> Click the left circle to receive connections<br>
          <strong>Output:</strong> Click the right circle to connect to other nodes
        </p>
      </div>
    `
  }

  getDelayPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Delay Configuration</h3>
      <div class="property-group">
        <label>Wait for</label>
        <div class="inline-fields">
          <input type="number" min="1" value="${node.config.duration || ''}" 
                 data-action="input->workflow-builder#updateNodeConfig" data-property="duration"
                 class="duration-input">
          <select data-action="change->workflow-builder#updateNodeConfig" data-property="unit"
                  class="unit-select">
            <option value="minutes" ${node.config.unit === 'minutes' ? 'selected' : ''}>Minutes</option>
            <option value="hours" ${node.config.unit === 'hours' ? 'selected' : ''}>Hours</option>
            <option value="days" ${node.config.unit === 'days' ? 'selected' : ''}>Days</option>
            <option value="weeks" ${node.config.unit === 'weeks' ? 'selected' : ''}>Weeks</option>
          </select>
        </div>
      </div>
    `
  }

  getConditionPropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Condition Configuration</h3>
      <div class="property-group">
        <label>Check If</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="condition_type">
          <option value="">Select what to check...</option>
          <option value="application_status_equals" ${node.config.condition_type === 'application_status_equals' ? 'selected' : ''}>Application status equals</option>
          <option value="days_since_created" ${node.config.condition_type === 'days_since_created' ? 'selected' : ''}>Days since created</option>
        </select>
      </div>
    `
  }

  getUpdatePropertiesHTML(node) {
    return `
      <h3 class="property-panel-title">Update Configuration</h3>
      <div class="property-group">
        <label>Field to Update</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="field">
          <option value="">Select field...</option>
          <option value="application_status" ${node.config.field === 'application_status' ? 'selected' : ''}>Application Status</option>
          <option value="user_notes" ${node.config.field === 'user_notes' ? 'selected' : ''}>User Notes</option>
          <option value="priority" ${node.config.field === 'priority' ? 'selected' : ''}>Priority</option>
        </select>
      </div>
      <div class="property-group">
        <label>New Value</label>
        <input type="text" value="${node.config.value || ''}" 
               data-action="input->workflow-builder#updateNodeConfig" data-property="value">
      </div>
    `
  }

  updateNodeConfig(event) {
    if (!this.selectedNode) return
    
    const property = event.target.dataset.property
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value
    
    this.selectedNode.config[property] = value
    
    // Update node display
    this.refreshNodeDisplay(this.selectedNode)
    
    // Refresh properties panel if trigger type changed
    if (property === 'trigger_type') {
      this.showNodeProperties(this.selectedNode)
    }
    
    this.updateFormData()
  }

  refreshNodeDisplay(node) {
    const nodeElement = document.querySelector(`[data-node-id="${node.id}"]`)
    if (nodeElement) {
      const descElement = nodeElement.querySelector('.node-description')
      if (descElement) descElement.textContent = this.getNodeDescription(node)
    }
  }

  deleteNode(event) {
    const nodeId = parseInt(event.target.dataset.nodeId)
    
    // Remove connections involving this node
    this.connections = this.connections.filter(conn => {
      if (conn.from == nodeId || conn.to == nodeId) {
        const pathElement = this.svgLayer.querySelector(`[data-connection-id="${conn.id}"]`)
        if (pathElement) pathElement.remove()
        return false
      }
      return true
    })
    
    // Remove node
    this.nodes = this.nodes.filter(node => node.id != nodeId)
    
    const nodeElement = document.querySelector(`[data-node-id="${nodeId}"]`)
    if (nodeElement) {
      nodeElement.remove()
    }
    
    // Clear properties if this was the selected node
    if (this.selectedNode && this.selectedNode.id == nodeId) {
      this.selectedNode = null
      this.propertiesTarget.querySelector('.panel-content').innerHTML = 
        '<p class="no-selection">Click on a node to configure its properties</p>'
      this.propertiesTarget.classList.remove('visible')
    }
    
    this.updateFormData()
  }

  handleCanvasClick(event) {
    if (event.target === this.canvasTarget || event.target === this.svgLayer) {
      this.clearSelection()
      if (this.connectingFrom) {
        this.clearConnectionFeedback()
        this.connectingFrom = null
      }
    }
  }

  clearSelection() {
    document.querySelectorAll('.workflow-node').forEach(node => {
      node.classList.remove('selected')
    })
    this.selectedNode = null
    const propertiesContent = this.propertiesTarget.querySelector('.panel-content')
    if (propertiesContent) {
      propertiesContent.innerHTML = '<p class="no-selection">Click on a node to configure its properties</p>'
    }
    this.propertiesTarget.classList.remove('visible')
  }

  // Enhanced quick action methods for building chains
  addQuickEmail() {
    const newNode = this.createNode('email', 100 + (this.nodes.length * 50), 100)
    this.selectNode(newNode)
  }

  addQuickDelay() {
    const newNode = this.createNode('delay', 100 + (this.nodes.length * 50), 100)
    this.selectNode(newNode)
  }

  addQuickCondition() {
    const newNode = this.createNode('condition', 100 + (this.nodes.length * 50), 100)
    this.selectNode(newNode)
  }

  getEmailTemplateOptions(selectedTemplateId) {
    if (!this.emailTemplatesValue || this.emailTemplatesValue.length === 0) {
      return '<option value="" disabled>No templates available</option>'
    }
    
    return this.emailTemplatesValue.map(template => {
      const selected = template.id == selectedTemplateId ? 'selected' : ''
      return `<option value="${template.id}" ${selected}>${template.name}</option>`
    }).join('')
  }

  getApplicationStatusChangeHTML(node) {
    const fromStatus = node.config.from_status || ''
    const toStatus = node.config.to_status || ''
    
    return `
      <div class="property-group">
        <label>From Status</label>
        <select data-action="change->workflow-builder#updateApplicationStatusConfig" data-property="from_status">
          <option value="">Select from status...</option>
          ${this.getStatusOptions(fromStatus)}
        </select>
      </div>
      <div class="property-group">
        <label>To Status</label>
        <select data-action="change->workflow-builder#updateNodeConfig" data-property="to_status">
          <option value="">Select to status...</option>
          ${this.getToStatusOptions(fromStatus, toStatus)}
        </select>
      </div>
    `
  }

  getApplicationStatuses() {
    return [
      { key: 'created', value: 0, label: 'Created' },
      { key: 'user_details', value: 1, label: 'User Details' },
      { key: 'property_details', value: 2, label: 'Property Details' },
      { key: 'income_and_loan_options', value: 3, label: 'Income and Loan Options' },
      { key: 'submitted', value: 4, label: 'Submitted' },
      { key: 'processing', value: 5, label: 'Processing' },
      { key: 'rejected', value: 6, label: 'Rejected' },
      { key: 'accepted', value: 7, label: 'Accepted' }
    ]
  }

  getStatusOptions(selectedStatus) {
    return this.getApplicationStatuses()
      .map(status => 
        `<option value="${status.key}" ${status.key === selectedStatus ? 'selected' : ''}>${status.label}</option>`
      ).join('')
  }

  getToStatusOptions(fromStatus, selectedToStatus) {
    if (!fromStatus) return ''
    
    const statuses = this.getApplicationStatuses()
    const fromStatusValue = statuses.find(s => s.key === fromStatus)?.value
    
    if (fromStatusValue === undefined) return ''
    
    return statuses
      .filter(status => status.value > fromStatusValue)
      .map(status => 
        `<option value="${status.key}" ${status.key === selectedToStatus ? 'selected' : ''}>${status.label}</option>`
      ).join('')
  }

  getContractStatuses() {
    return [
      { key: 'awaiting_funding', value: 0, label: 'Awaiting Funding' },
      { key: 'awaiting_investment', value: 1, label: 'Awaiting Investment' },
      { key: 'ok', value: 2, label: 'OK' },
      { key: 'in_holiday', value: 3, label: 'In Holiday' },
      { key: 'in_arrears', value: 4, label: 'In Arrears' },
      { key: 'complete', value: 5, label: 'Complete' }
    ]
  }

  updateApplicationStatusConfig(event) {
    if (!this.selectedNode) return
    
    const property = event.target.dataset.property
    const value = event.target.value
    
    this.selectedNode.config[property] = value
    
    // If from_status changed, reset to_status and update options
    if (property === 'from_status') {
      this.selectedNode.config.to_status = ''
      this.showNodeProperties(this.selectedNode)
    }
    
    this.refreshNodeDisplay(this.selectedNode)
    this.updateFormData()
  }

  loadExistingWorkflow() {
    if (this.workflowDataValue && this.workflowDataValue.trim()) {
      try {
        const workflowData = JSON.parse(this.workflowDataValue)
        
        // Load nodes
        if (workflowData.nodes) {
          workflowData.nodes.forEach(nodeData => {
            this.nodes.push(nodeData)
            this.nextNodeId = Math.max(this.nextNodeId, nodeData.id + 1)
            this.renderNode(nodeData)
          })
        }
        
        // Load connections
        if (workflowData.connections) {
          this.connections = workflowData.connections
          this.connections.forEach(connection => {
            this.drawConnection(connection)
          })
        }
      } catch (error) {
        console.error('Failed to load existing workflow:', error)
      }
    }
    
    // Always ensure at least a trigger node exists
    if (this.nodes.length === 0) {
      this.createNode('trigger', 100, 100)
    }
  }

  updateFormData() {
    const workflowData = {
      nodes: this.nodes,
      connections: this.connections,
      version: '2.0'
    }
    
    // Update trigger type in main form
    if (this.nodes.length > 0 && this.nodes[0].type === 'trigger') {
      const triggerTypeField = document.querySelector('#email_workflow_trigger_type')
      if (triggerTypeField) {
        triggerTypeField.value = this.nodes[0].config.trigger_type || ''
      }
    }
    
    // Store workflow data in hidden field
    const hiddenField = document.getElementById('workflow_builder_data')
    if (hiddenField) {
      hiddenField.value = JSON.stringify(workflowData)
    }
  }

  hideCanvasHint() {
    const canvasHint = this.canvasTarget.querySelector('.canvas-hint')
    if (canvasHint && this.nodes.length > 0) {
      canvasHint.style.display = 'none'
    }
  }

  disconnect() {
    console.log("Enhanced Workflow Builder disconnected")
  }
}