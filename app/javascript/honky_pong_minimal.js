// Honky Pong - Minimal adaptation of working Donkey Kong game
// Original working code with minimal Rails integration changes

export class HonkyPongMinimal {
  constructor(options = {}) {
    this.container = options.container;
    
    if (!this.container) {
      throw new Error('Game container not found!');
    }
    
    this.init();
  }
  
  init() {
    // Get asset paths from data attributes
    this.assetPaths = {
      donkeyKong: this.container.dataset.assetDonkeyKong,
      mono: this.container.dataset.assetMono,
      barriles: this.container.dataset.assetBarriles,
      heart: this.container.dataset.assetHeart,
      hearts: this.container.dataset.assetHearts,
      hammer: this.container.dataset.assetHammer
    };
    
    this.start();
  }
  
  start() {
    let lives = 1;
    let puntuacion = 0;
    let contRight = 0;
    
    let pressKey = {
      ArrowLeft: false,
      ArrowUp: false,
      ArrowRight: false,
    };
    
    this.container.classList.remove("game-over");
    this.showGame();
    
    const mario = document.querySelector(".mario");
    const containerMono = document.querySelector(".container-kong");
    
    // listeners
    document.addEventListener("keydown", (e) => {
      const key = e.code;
      if (!mario.matches(".no-move")) {
        for (let i in pressKey) {
          if (i === key) {
            pressKey[i] = true;
            handleM();
          } else {
            pressKey[i] = false;
          }
        }
        updateMarioPosition();
      }
    });
    
    document.addEventListener("keyup", () => {
      if (!mario.matches(".no-move")) {
        for (let i in pressKey) {
          pressKey[i] = false;
          handleM();
        }
        updateMarioPosition();
        downFloor();
      }
    });

    function updateMarioPosition() {
      // Remove existing position classes
      mario.classList.remove('pos-left', 'pos-center', 'pos-right', 'pos-far-right');
      
      // Add appropriate position class based on contRight value
      if (contRight < -50) {
        mario.classList.add('pos-left');
      } else if (contRight > 150) {
        mario.classList.add('pos-far-right');
      } else if (contRight > 50) {
        mario.classList.add('pos-right');
      } else {
        mario.classList.add('pos-center');
      }
    }
    
    function handleM() {
      for (let i in pressKey) {
        if (i === "ArrowLeft") {
          moveLeft(pressKey[i]);
        } else if (i === "ArrowUp") {
          moveUp(pressKey[i]);
          getMartillo();
        } else if (i === "ArrowRight") {
          moveRight(pressKey[i]);
        }
      }
    }

    function moveRight(status) {
      if (status && !mario.matches(".no-move")) {
        contRight += 5;
        if (mario.classList.contains("martillo")) {
          mario.classList.remove("view-left");
          mario.classList.remove("martillo-left");
          mario.classList.add("martillo-right");
        } else {
          mario.classList.add("right");
          mario.classList.remove("view-left");
        }
      } else {
        mario.classList.remove("right");
      }
    }

    function moveLeft(status) {
      if (status && !mario.matches(".no-move")) {
        contRight -= 5;
        if (mario.classList.contains("martillo")) {
          mario.classList.remove("martillo-right");
          mario.classList.remove("view-right");
          mario.classList.add("martillo-left");
        } else {
          mario.classList.add("view-left");
          mario.classList.add("left");
        }
      } else {
        mario.classList.remove("left");
      }
    }
    
    function moveUp(status) {
      if (status && !mario.matches(".no-move")) {
        if (mario.classList.contains("view-left")) {
          mario.classList.add("up-left");
        } else {
          mario.classList.add("up");
          mario.classList.remove("up-left");
        }
      } else {
        mario.classList.remove("up");
        mario.classList.remove("up-left");
      }
    }

    function newBarril() {
      xyBarril();
      const div = document.createElement("div");
      div.className = "new-barril";
      if (!document.querySelector(".new-barril")) {
        containerMono.appendChild(div);
        setTimeout(() => {
          div.remove();
          clearInterval(positions);
        }, 3000);
      }
    }
    
    const newBarrilTime = setInterval(() => {
      newBarril();
    }, 2000);

    setTimeout(newBarril, 2100);
    
    let positions;

    function xyBarril() {
      positions = setInterval(() => {
        if (document.querySelector(".new-barril")) {
          const pBarril = document.querySelector(".new-barril");
          const mario = document.querySelector(".mario");
          
          const pxM = Math.floor(mario.getBoundingClientRect().x);
          const prM = Math.floor(mario.getBoundingClientRect().right);
          const pyM = Math.floor(mario.getBoundingClientRect().y);
          const pxB = Math.floor(pBarril.getBoundingClientRect().x);
          const pyB = Math.floor(pBarril.getBoundingClientRect().y - 37);

          // explotar el barril
          if (mario.classList.contains("martillo-left")) {
            if (pxB - pxM <= 60 && pxB - pxM > 0 && pyB - pyM < 40) {
              mario.classList.add("blink");
              pBarril.remove();
              setTimeout(() => {
                lives--;
                deleteLives();
                mario.classList.remove("blink");
                clearInterval(positions);
              }, 1000);
            }
          } else if (mario.classList.contains("martillo")) {
            if (pxB - pxM <= 60 && pxB - pxM > 0 && pyB - pyM < 40) {
              score();
              pBarril.remove();
              clearInterval(positions);
            }
          } else if (pxB - pxM <= 60 && pxB - pxM > 0 && pyB - pyM < 40) {
            mario.classList.add("blink");
            pBarril.remove();
            setTimeout(() => {
              lives--;
              deleteLives();
              mario.classList.remove("blink");
              clearInterval(positions);
            }, 1000);
          }
          
          if (pxB < 0) {
            pBarril.remove();
            clearInterval(positions);
          }
          
          if (lives === 0) {
            gameOver();
            clearInterval(positions);
            clearInterval(newBarrilTime);
          }
        } else {
          clearInterval(positions);
        }
      });
    }
    
    function getMartillo() {
      if (document.querySelector(".img-martillo")) {
        const pMario = mario.getBoundingClientRect();
        const pMartillo = document.querySelector(".img-martillo").getBoundingClientRect();
        const pMartx = Math.floor(pMartillo.x);
        const pMarty = Math.floor(pMartillo.y);
        const pMariox = Math.floor(pMario.x) + 35;
        const pMarioy = Math.floor(pMario.y);
        
        if (pMariox >= pMartx && pMariox <= pMartx + 50 && pMarioy - pMarty < 10) {
          document.querySelector(".img-martillo").remove();
          mario.classList.add("martillo");
        }
      }
    }

    function deleteLives() {
      if (document.querySelector(".content-lives img")) {
        const divLives = document.querySelector(".content-lives img");
        divLives.remove();
      }
    }

    function score() {
      puntuacion += 500;
      const puntuacionP = document.querySelector(".puntuacion p");
      puntuacionP.textContent = puntuacion;
    }
    
    const hearts = () => {
      const peach = document.querySelector(".peach");
      const img = document.createElement("img");
      img.className = "hearts";
      img.src = this.assetPaths.hearts;
      img.height = 40;
      img.width = 40;
      setTimeout(() => {
        peach.appendChild(img);
      }, 2000);
    }
    
    function downFloor() {
      if (document.querySelector(".floor-right")) {
        const pMario = mario.getBoundingClientRect();
        const pFloor = document.querySelector(".floor-right").getBoundingClientRect();
        const pxMario = Math.floor(pMario.x);
        const pxFloor = Math.floor(pFloor.x);

        if (pxFloor - pxMario < 90) {
          document.querySelector(".floor-right").classList.add("animate__animated", "animate__fadeOutDownBig");
          document.querySelector(".container-kong").classList.add("animate__animated", "animate__fadeOutDownBig");
          document.querySelector(".peach").classList.add("peach-down");
          mario.className = "mario no-move";
          puntuacion += 2500;
          contRight -= 20;
          updateMarioPosition();
          score();
          hearts();
          setTimeout(() => {
            that.reiniciarGame();
          }, 7000);
        }
      }
    }
    
    const that = this;
    
    function gameOver() {
      that.container.classList.add("game-over");
      while (that.container.firstChild) {
        that.container.removeChild(that.container.firstChild);
      }
      const btn = document.createElement("button");
      btn.className = "btn-start restart";
      btn.onclick = () => that.start();
      btn.textContent = "Restart";
      that.container.appendChild(btn);
    }
    
    this.addLives();
    this.martillo();
  }
  
  showGame() {
    this.container.className = "entorno play";
    this.container.innerHTML = `
      <div class="puntuacion">
        <h5>Score</h5>
        <p>0</p>
      </div>
      <div class="images">
        <div class="mario"></div>
        <div class="container-kong">
          <img class="mono" src="${this.assetPaths.mono}" alt="mono" height="160" width="160px">
          <img class="barriles" src="${this.assetPaths.barriles}" alt="barriles" height="140" width="140">
        </div>
      </div>
      <div class="floor"></div>
      <div class="floor-right"></div> 
      <div class="peach"></div> 
    `;
  }
  
  addLives() {
    const divLives = document.createElement("div");
    divLives.className = "content-lives";
    
    const img = document.createElement("img");
    img.src = this.assetPaths.heart;
    img.height = "30";
    img.width = "30";
    divLives.appendChild(img);
    
    this.container.appendChild(divLives);
  }
  
  reiniciarGame() {
    this.container.className = "entorno";
    this.container.innerHTML = `
      <img class="donkey-kong-banner" src="${this.assetPaths.donkeyKong}" alt="donkey donkey-kong" height="200px">
    `;
    const btn = document.createElement("button");
    btn.className = "btn-start restart";
    btn.onclick = () => this.start();
    btn.textContent = "Start";
    this.container.appendChild(btn);
  }
  
  martillo() {
    const img = document.createElement("img");
    img.className = "img-martillo";
    img.src = this.assetPaths.hammer;
    img.height = "60";
    img.width = "60";
    this.container.appendChild(img);
  }
  
  destroy() {
    // Clean up method
  }
}