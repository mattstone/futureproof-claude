# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/admin", under: "admin"
pin "honky_pong", to: "honky_pong.js"
pin "honky_pong_authentic", to: "honky_pong_authentic.js"
pin "honky_pong_fresh", to: "honky_pong_fresh.js"
pin "honky_pong_simple", to: "honky_pong_simple.js"
pin "honky_pong_simple_fixed", to: "honky_pong_simple_fixed.js"
pin "honky_pong_minimal", to: "honky_pong_minimal.js"
pin "honky_pong_enhanced", to: "honky_pong_enhanced.js"
pin "lace_invaders", to: "lace_invaders.js"
pin "hackman", to: "hackman.js"
pin "audio_manager", to: "audio_manager.js"
pin "admin_email_workflows", to: "admin_email_workflows.js"
pin "workflow_templates", to: "workflow_templates.js"
pin "email_workflows_entry", to: "email_workflows_entry.js"
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js", preload: true
pin "tinymce", to: "https://cdn.tiny.cloud/1/#{Rails.application.credentials.TINYMCE_API_KEY}/tinymce/6/tinymce.min.js", preload: true
pin "d3" # @7.9.0
pin "d3-array" # @3.2.4
pin "d3-axis" # @3.0.0
pin "d3-brush" # @3.0.0
pin "d3-chord" # @3.0.1
pin "d3-color" # @3.1.0
pin "d3-contour" # @4.0.2
pin "d3-delaunay" # @6.0.4
pin "d3-dispatch" # @3.0.1
pin "d3-drag" # @3.0.0
pin "d3-dsv" # @3.0.1
pin "d3-ease" # @3.0.1
pin "d3-fetch" # @3.0.1
pin "d3-force" # @3.0.0
pin "d3-format" # @3.1.0
pin "d3-geo" # @3.1.1
pin "d3-hierarchy" # @3.1.2
pin "d3-interpolate" # @3.0.1
pin "d3-path" # @3.1.0
pin "d3-polygon" # @3.0.1
pin "d3-quadtree" # @3.0.1
pin "d3-random" # @3.0.1
pin "d3-scale" # @4.0.2
pin "d3-scale-chromatic" # @3.1.0
pin "d3-selection" # @3.0.0
pin "d3-shape" # @3.2.0
pin "d3-time" # @3.1.0
pin "d3-time-format" # @4.1.0
pin "d3-timer" # @3.0.1
pin "d3-transition" # @3.0.1
pin "d3-zoom" # @3.0.0
pin "delaunator" # @5.0.1
pin "internmap" # @2.0.3
pin "robust-predicates" # @3.0.2
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
