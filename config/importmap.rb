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
pin "lace_invaders", to: "lace_invaders.js"
pin "hackman", to: "hackman.js"
pin "audio_manager", to: "audio_manager.js"
pin "chart.js", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.js", preload: true
