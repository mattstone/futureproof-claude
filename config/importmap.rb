# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/admin", under: "admin"
pin "honky_pong", to: "honky_pong.js"
pin "lace_invaders", to: "lace_invaders.js"
pin "hackman", to: "hackman.js"
pin "audio_manager", to: "audio_manager.js"
