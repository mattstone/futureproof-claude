const btnStart = document.querySelector(".btn-start");
const entorno = document.querySelector(".entorno");

window.onresize = () => {
  if (window.innerWidth > 1024) {
  }
};
function UI() {}
btnStart.addEventListener("click", () => {
  btnStart.setAttribute("hidden", true);
  playGame();
});
let lives;

let contRight;
let puntuacion;
// funciones fundamentales
function start() {
  addLives();
  let key;
  lives = 1;
  puntuacion = 0;
  contRight = 0;
  let positions;
  let pressKey = {
    ArrowLeft: false,
    ArrowUp: false,
    ArrowDown: false,
    ArrowRight: false,
  };
  entorno.classList.remove("game-over");
  const mario = document.querySelector(".mario");

  const containerMono = document.querySelector(".container-kong");

  // listeners
  document.addEventListener("keydown", (e) => {
    key = e.code;
    if (!mario.matches(".no-move")) {
      for (i in pressKey) {
        if (i === key) {
          pressKey[i] = true;
          handleM();
        } else {
          pressKey[i] = false;
        }
      }

      mario.setAttribute("style", `--contRight:${contRight}px`);
    }
  });
  document.addEventListener("keyup", () => {
    if (!mario.matches(".no-move")) {
      for (i in pressKey) {
        pressKey[i] = false;
        handleM();
      }
      mario.setAttribute("style", `--contRight:${contRight}px`);
      downFloor();
    }
  });

  function handleM() {
    for (i in pressKey) {
      if (i === "ArrowLeft") {
        moveLeft(pressKey[i]);
      } else if (i === "ArrowUp") {
        moveUp(pressKey[i]);
        getMartillo();
      } else if (i === "ArrowDown") {
        moveDown(pressKey[i]);
      } else if (i === "ArrowRight") {
        moveRight(pressKey[i]);
      }
    }
  }
  
  // Add down movement for ladder climbing
  function moveDown(status) {
    if (status && !mario.matches(".no-move")) {
      const nearLadder = checkLadderProximity(mario);
      
      if (nearLadder) {
        mario.classList.add("climbing");
        mario.classList.remove("right", "left", "view-left");
        
        // Move Mario down along the ladder
        const currentBottom = parseInt(mario.style.bottom || "0");
        mario.style.bottom = Math.max(0, currentBottom - 3) + "px";
        
        checkPlatformLanding(mario);
      }
    } else {
      mario.classList.remove("climbing");
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
      // Check if Mario is near a ladder for climbing
      const nearLadder = checkLadderProximity(mario);
      
      if (nearLadder) {
        // Enhanced ladder climbing mechanics
        mario.classList.add("climbing");
        mario.classList.remove("right", "left", "view-left");
        
        // Move Mario up along the ladder
        const currentBottom = parseInt(mario.style.bottom || "0");
        mario.style.bottom = (currentBottom + 3) + "px";
        
        // Check if reached next platform level
        checkPlatformLanding(mario);
      } else {
        // Regular jump mechanics (preserved from original)
        mario.style.transform = `translatex(${contRight}px)`;
        if (mario.classList.contains("view-left")) {
          mario.classList.add("up-left");
        } else {
          mario.classList.add("up");
          mario.classList.remove("up-left");
        }
      }
    } else {
      mario.classList.remove("up", "up-left", "climbing");
    }
  }
  
  // Enhanced ladder climbing system
  function checkLadderProximity(mario) {
    const marioRect = mario.getBoundingClientRect();
    const ladders = document.querySelectorAll('.ladder');
    
    for (let ladder of ladders) {
      const ladderRect = ladder.getBoundingClientRect();
      const horizontalOverlap = Math.abs(marioRect.left + marioRect.width/2 - (ladderRect.left + ladderRect.width/2)) < 40;
      const verticalOverlap = marioRect.bottom >= ladderRect.top && marioRect.top <= ladderRect.bottom;
      
      if (horizontalOverlap && verticalOverlap) {
        return ladder;
      }
    }
    return null;
  }
  
  function checkPlatformLanding(mario) {
    const marioRect = mario.getBoundingClientRect();
    const platforms = document.querySelectorAll('.platform');
    
    for (let platform of platforms) {
      const platformRect = platform.getBoundingClientRect();
      const onPlatform = Math.abs(marioRect.bottom - platformRect.top) < 10 && 
                        marioRect.left < platformRect.right && 
                        marioRect.right > platformRect.left;
      
      if (onPlatform) {
        mario.style.bottom = (window.innerHeight - platformRect.top - 100) + "px";
        mario.classList.remove("climbing");
        break;
      }
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

  function xyBarril() {
    positions = setInterval(() => {
      if (document.querySelector(".new-barril")) {
        const pBarril = document.querySelector(".new-barril");

        const mario = document.querySelector(".mario");
        // console.log(entorno.getBoundingClientRect().x)
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
      const pMartillo = document
        .querySelector(".img-martillo")
        .getBoundingClientRect();
      const pMartx = Math.floor(pMartillo.x);
      const pMarty = Math.floor(pMartillo.y);
      const pMariox = Math.floor(pMario.x) + 35;
      const pMarioy = Math.floor(pMario.y);
      if (
        pMariox >= pMartx &&
        pMariox <= pMartx + 50 &&
        pMarioy - pMarty < 10
      ) {
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
  function hearts() {
    const peach = document.querySelector(".peach");
    const img = document.createElement("img");
    img.className = "hearts";
    img.src = "../images/hearts.png";
    img.height = 40;
    img.width = 40;
    setTimeout(() => {
      peach.appendChild(img);
    }, 2000);
  }
  function downFloor() {
    // Enhanced princess rescue mechanics for top level
    const pMario = mario.getBoundingClientRect();
    const pPeach = document.querySelector(".peach").getBoundingClientRect();
    
    // Check if Mario reaches the princess on level 5
    const horizontalDistance = Math.abs(pMario.left - pPeach.left);
    const verticalDistance = Math.abs(pMario.top - pPeach.top);
    
    if (horizontalDistance < 100 && verticalDistance < 50) {
      // Princess rescue sequence!
      document
        .querySelector(".container-kong")
        .classList.add("animate__animated", "animate__fadeOutDownBig");
      document.querySelector(".peach").classList.add("peach-down");
      mario.className = "mario no-move";
      puntuacion += 5000; // Bonus for reaching top level!
      mario.setAttribute("style", `--contRight:${contRight}px`);
      score();
      hearts();
      
      // Show victory message
      setTimeout(() => {
        alert("🎉 Congratulations! You rescued the Princess! 🎉");
        reiniciarGame();
      }, 3000);
      
      setTimeout(() => {
        reiniciarGame();
      }, 7000);
    }
  }
  
  // Enhanced collision detection for platforms
  function checkPlatformCollision(mario) {
    const marioRect = mario.getBoundingClientRect();
    const platforms = document.querySelectorAll('.platform');
    
    for (let platform of platforms) {
      const platformRect = platform.getBoundingClientRect();
      
      // Check if Mario is standing on this platform
      const isOnPlatform = 
        marioRect.bottom >= platformRect.top - 5 &&
        marioRect.bottom <= platformRect.top + 10 &&
        marioRect.left < platformRect.right &&
        marioRect.right > platformRect.left;
        
      if (isOnPlatform) {
        return platform;
      }
    }
    return null;
  }
}

function addLives() {
  const divLives = document.createElement("div");
  divLives.className = "content-lives";
  divLives.style = ` 
  position: absolute;
  top: 1em;
  right: 1em; 
`;
  for (let i = 1; i <= 1; i++) {
    const img = document.createElement("img");
    img.style = `
    margin-right: 5px;
  `;
    img.src = "./images/heart.png";
    img.height = "30";
    img.width = "30";
    divLives.appendChild(img);
  }
  entorno.appendChild(divLives);
}
function gameOver() {
  entorno.classList.add("game-over");
  while (entorno.firstChild) {
    entorno.removeChild(entorno.firstChild);
  }
  const btn = document.createElement("button");
  btn.className = "btn-start restart animate__animated animate__tada";
  btn.onclick = playGame;
  btn.textContent = "Restart";
  entorno.appendChild(btn);
}
function reiniciarGame() {
  entorno.className = "entorno";
  entorno.innerHTML = `
  <img class="donkey-kong-banner animate__animated animate__bounceInDown" src="./images/donkey-kong.png" alt="donkey donkey-kong" height="200px">
  `;
  const btn = document.createElement("button");
  btn.className = "btn-start restart animate__animated animate__tada";
  btn.onclick = playGame;
  btn.textContent = "Start";
  entorno.appendChild(btn);
}
function martillo() {
  const img = document.createElement("img");
  img.className = "img-martillo";
  img.style = ` 
    position: absolute;
    top: 60%;
    right: 80%;  
  `;
  img.src = "./images/martillo.png";
  img.height = "60";
  img.width = "60";
  entorno.appendChild(img);
}

function playGame() {
  entorno.className = "entorno play";
  entorno.innerHTML = `
      <div class="puntuacion">
        <h5>Score</h5>
        <p></p>
      </div>
      
      <!-- Enhanced Multi-Level Platform System -->
      <div class="platform platform-level-1"></div>
      <div class="platform platform-level-2"></div>
      <div class="platform platform-level-3"></div>
      <div class="platform platform-level-4"></div>
      <div class="platform platform-level-5"></div>
      
      <!-- Ladder System -->
      <div class="ladder ladder-1-2"></div>
      <div class="ladder ladder-2-3"></div>
      <div class="ladder ladder-3-4"></div>
      <div class="ladder ladder-4-5"></div>
      
      <!-- Level Indicators (for gameplay clarity) -->
      <div class="level-indicator level-indicator-1">Level 1</div>
      <div class="level-indicator level-indicator-2">Level 2</div>
      <div class="level-indicator level-indicator-3">Level 3</div>
      <div class="level-indicator level-indicator-4">Level 4</div>
      <div class="level-indicator level-indicator-5">Level 5</div>
      
      <div class="images">
        <div class="mario"></div>
        <div class="container-kong enhanced-kong-position">
          <img
            class="mono"
            src="./images/mono.gif"
            alt="mono"
            height="160"
            width="160px"
          />
          <img
            class="barriles barrel-spawn-top"
            src="./images/barriles.png"
            alt="barriles"
            height="140"
            width="140"
          />
        </div>       
      </div>
      
      <!-- Princess at top level -->
      <div class="peach enhanced-princess"></div> 
`;
  martillo();
  start();
}
