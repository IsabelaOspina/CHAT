const usuario = { nombre: null, sala: null };
let intervalo = null;

function mostrarChat() {
  document.getElementById('login').style.display = 'none';
  document.getElementById('chat').style.display = '';
  // Iniciar polling de mensajes
  if (intervalo) clearInterval(intervalo);
  intervalo = setInterval(() => {
    if (usuario.sala) verHistorial(true);
  }, 1000);
  // Mostrar nombre de la sala si existe
  actualizarNombreSala();
  // Quitar localStorage: no guardar usuario registrado
}

function mostrarLogin(msg = "") {
  document.getElementById('login').style.display = '';
  document.getElementById('chat').style.display = 'none';
  document.getElementById('login-msg').innerText = msg;
  if (intervalo) clearInterval(intervalo);

  const btnRegistrar = document.querySelector('button.registrar');
  const btnEntrar = document.querySelector('button.login');
  const btnCambiar = document.getElementById('cambiar-usuario');
  // Habilita siempre el botón Entrar, y el de Registrar
  btnRegistrar.style.display = '';
  btnEntrar.style.display = '';
  btnCambiar && (btnCambiar.style.display = 'none');
  document.getElementById('nombre').value = '';
  document.getElementById('contraseña').value = '';
}

function cambiarUsuario() {
  // Quitar localStorage: no borrar usuario registrado
  mostrarLogin();
}

function registrar() {
  const nombreInput = document.getElementById('nombre');
  const contraseñaInput = document.getElementById('contraseña');
  const nombre = nombreInput.value.trim();
  const contraseña = contraseñaInput.value.trim();
  if (!nombre || !contraseña) {
    document.getElementById('login-msg').innerText = "El usuario y la contraseña no pueden estar vacíos.";
    return;
  }
  fetch('/usuario', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ nombre, contraseña })
  })
    .then(r => r.json())
    .then(data => {
      if (data.ok) {
        document.getElementById('login-msg').innerText = "Usuario registrado correctamente. Ahora puedes entrar.";
      } else {
        if (
          (data.error && data.error.includes("ya está registrado")) ||
          (data.error && data.error.includes("already_started"))
        ) {
          document.getElementById('login-msg').innerText = "El usuario ya está registrado. Usa Entrar.";
        } else {
          document.getElementById('login-msg').innerText = data.error || "Error al registrar.";
        }
      }
    });
}

function login() {
  const nombreInput = document.getElementById('nombre');
  const contraseñaInput = document.getElementById('contraseña');
  const nombre = nombreInput.value.trim();
  const contraseña = contraseñaInput.value.trim();
  if (!nombre || !contraseña) {
    document.getElementById('login-msg').innerText = "El usuario y la contraseña no pueden estar vacíos.";
    return;
  }
  fetch('/usuario/reconectar', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ nombre, contraseña })
  })
    .then(r => r.json())
    .then(data => {
      if (data.ok) {
        usuario.nombre = nombre;
        document.getElementById('login-msg').innerText = "";
        mostrarChat();
        listarUsuarios();
      } else {
        // No intentes forzar el acceso si el backend responde 401
        if (data.error && data.error.includes("Credenciales incorrectas")) {
          document.getElementById('login-msg').innerText = "Usuario o contraseña incorrectos, o usuario no registrado.";
        } else if (data.error && data.error.includes("El usuario ya está registrado")) {
          document.getElementById('login-msg').innerText = "El usuario ya está registrado. Usa Entrar.";
        } else {
          document.getElementById('login-msg').innerText = data.error || "No se pudo iniciar sesión.";
        }
      }
    });
}

function crearSala() {
  const nombre = document.getElementById('sala').value;
  fetch('/sala', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ nombre })
  })
    .then(r => r.json())
    .then(data => alert(data.ok ? "Sala creada" : data.error));
}

function unirseSala() {
  const sala = document.getElementById('sala').value;
  fetch('/sala/unirse', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ usuario: usuario.nombre, sala })
  })
    .then(r => r.json())
    .then(data => {
      if (data.ok) {
        usuario.sala = sala;
        document.getElementById('mensajes').innerHTML = '';
        cerrarModalBusqueda();
        actualizarNombreSala();
        verHistorial(true);
        listarUsuarios(); // Actualiza la lista de usuarios conectados
      } else {
        alert(data.error);
      }
    });
}

function abandonarSala() {
  fetch('/sala/abandonar', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ usuario: usuario.nombre })
  })
    .then(r => r.json())
    .then(data => {
      if (data.ok) {
        usuario.sala = null;
        document.getElementById('mensajes').innerHTML = '';
        actualizarNombreSala();
        listarUsuarios(); // Actualiza la lista de usuarios conectados
      } else {
        alert(data.error);
      }
    });
}

function verHistorial(silent) {
  if (!usuario.sala) {
    if (!silent) alert("Únete a una sala primero");
    return;
  }
  fetch(`/sala/${usuario.sala}/historial`)
    .then(r => r.json())
    .then(data => {
      const mensajes = data.historial || [];
      if (silent === true) {
        agregarMensajesAlChat(mensajes);
      } else {
        const modal = document.getElementById('modal-busqueda');
        const resultados = document.getElementById('resultados-busqueda');
        resultados.innerHTML = mensajes.length
          ? mensajes.map(m => `<div>${m}</div>`).join('')
          : '<div>No hay mensajes en la sala.</div>';
        modal.style.display = 'flex';
      }
    });
}

function buscarMensajes() {
  if (!usuario.sala) return alert("Únete a una sala primero");
  const palabra = document.getElementById('buscar-palabra').value.trim();
  if (!palabra) {
    // Si el input está vacío, no mostrar nada en el modal
    const modal = document.getElementById('modal-busqueda');
    const resultados = document.getElementById('resultados-busqueda');
    resultados.innerHTML = '<div>Ingresa una palabra para buscar.</div>';
    modal.style.display = 'flex';
    return;
  }
  fetch(`/sala/${usuario.sala}/buscar?palabra=${encodeURIComponent(palabra)}`)
    .then(r => r.json())
    .then(data => {
      const mensajes = data.mensajes || [];
      const modal = document.getElementById('modal-busqueda');
      const resultados = document.getElementById('resultados-busqueda');
      resultados.innerHTML = mensajes.length
        ? mensajes.map(m => `<div>${m}</div>`).join('')
        : '<div>No se encontraron mensajes.</div>';
      modal.style.display = 'flex';
    });
}

function cerrarModalBusqueda() {
  document.getElementById('modal-busqueda').style.display = 'none';
}

function listarUsuarios() {
  fetch('/usuarios')
    .then(r => r.json())
    .then(data => {
      const ul = document.getElementById('usuarios');
      ul.innerHTML = '';
      (data.usuarios || []).forEach(u => {
        const li = document.createElement('li');
        // Crear avatar: círculo con la inicial del usuario
        const avatar = document.createElement('span');
        avatar.textContent = u[0] ? u[0].toUpperCase() : '?';
        avatar.style.display = 'inline-flex';
        avatar.style.alignItems = 'center';
        avatar.style.justifyContent = 'center';
        avatar.style.width = '26px';
        avatar.style.height = '26px';
        avatar.style.borderRadius = '50%';
        avatar.style.background = '#3182ce';
        avatar.style.color = '#fff';
        avatar.style.fontWeight = 'bold';
        avatar.style.fontSize = '15px';
        avatar.style.marginRight = '8px';
        li.appendChild(avatar);
        li.appendChild(document.createTextNode(u));
        ul.appendChild(li);
      });
    });
}

function enviarMensaje() {
  if (!usuario.sala) return alert("Únete a una sala primero");
  const mensaje = document.getElementById('mensaje').value;
  fetch('/mensaje', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ usuario: usuario.nombre, sala: usuario.sala, mensaje })
  });
  document.getElementById('mensaje').value = '';
  setTimeout(() => verHistorial(true), 500);
}

function logout() {
  usuario.nombre = null;
  usuario.sala = null;
  document.getElementById('nombre').value = '';
  document.getElementById('contraseña').value = '';
  mostrarLogin();
}

function actualizarNombreSala() {
  const nombreSalaDiv = document.getElementById('nombre-sala');
  if (usuario.sala) {
    nombreSalaDiv.textContent = `Sala: ${usuario.sala}`;
  } else {
    nombreSalaDiv.textContent = '';
  }
}

function renderMensaje(fecha, sala, usuario, texto) {
  // Obtiene la inicial del usuario para el icono
  const inicial = usuario.trim().charAt(0).toUpperCase();
  // Formatea la fecha (sin corchetes)
  const fechaFormateada = fecha.replace(/[\[\]]/g, '');
  // Crea el HTML del mensaje
  return `
    <div class="mensaje-chat">
      <span class="fecha">${fechaFormateada}</span>
      <span class="sala">#${sala}</span>
      <span class="usuario">
        <span class="usuario-icono">${inicial}</span>
      </span>
      <span class="texto">${texto}</span>
    </div>
  `;
}

function agregarMensajesAlChat(mensajes) {
  const mensajesDiv = document.getElementById('mensajes');
  mensajesDiv.innerHTML = '';
  mensajes.forEach(msg => {
    // Extrae partes usando regex
    const match = msg.match(/^\[(.*?)\] \[(.*?)\] (.*?): (.*)$/);
    if (match) {
      const [, fecha, sala, usuario, texto] = match;
      mensajesDiv.innerHTML += renderMensaje(fecha, sala, usuario, texto);
    } else {
      // Si no coincide, muestra el mensaje tal cual
      mensajesDiv.innerHTML += `<div class="mensaje-chat"><span class="texto">${msg}</span></div>`;
    }
  });
}

// Asegura que las funciones estén disponibles globalmente para el HTML
window.registrar = registrar;
window.login = login;
window.cambiarUsuario = typeof cambiarUsuario !== "undefined" ? cambiarUsuario : function() {};
window.crearSala = crearSala;
window.unirseSala = unirseSala;
window.abandonarSala = abandonarSala;
window.buscarMensajes = buscarMensajes;
window.verHistorial = verHistorial;
window.listarUsuarios = listarUsuarios;
window.enviarMensaje = enviarMensaje;
window.logout = logout;
window.cerrarModalBusqueda = cerrarModalBusqueda;
