// ── CONFIGURAÇÃO DE BANCO DE DADOS (API) ──
// Quando seu backend estiver pronto, mude para true e aponte para sua URL
const USAR_API_REAL = false; 
const API_BASE_URL = 'http://localhost:3000/api'; 

// ── DADOS PARA TESTE (FALLBACK ENQUANTO NÃO HÁ BANCO) ──
let COLABORADORES = [
  { id: 'u1', nome: 'Ana Paula Ferreira', matricula: '1001', perfil: 'Operador', status: 'Ativo' },
  { id: 'u2', nome: 'Carlos Eduardo Silva', matricula: '1002', perfil: 'Operador', status: 'Ativo' },
  { id: 'u3', nome: 'Marcos Antônio Costa', matricula: '1003', perfil: 'Operador', status: 'Ativo' },
  { id: 'u4', nome: 'Fernanda Lima', matricula: '1004', perfil: 'Operador', status: 'Inativo' },
  { id: 'u5', nome: 'Roberto Nascimento', matricula: '2001', perfil: 'Administrador', status: 'Ativo' },
];

let DOCUMENTOS = [
  { id: 'd1', titulo: 'ASO', userId: 'u1', dataValidade: '2025-03-10', dataEmissao: '2024-03-10' },
  { id: 'd2', titulo: 'CNH', userId: 'u1', dataValidade: '2026-08-15', dataEmissao: '2021-08-15' },
  { id: 'd3', titulo: 'Toxicológico', userId: 'u2', dataValidade: '2025-06-20', dataEmissao: '2024-06-20' },
  { id: 'd4', titulo: 'NR-35', userId: 'u2', dataValidade: '2026-12-01', dataEmissao: '2024-12-01' },
  { id: 'd5', titulo: 'ASO', userId: 'u3', dataValidade: '2026-02-28', dataEmissao: '2025-02-28' },
  { id: 'd6', titulo: 'NR-11', userId: 'u3', dataValidade: '2025-05-30', dataEmissao: '2024-05-30' },
];

let EQUIPAMENTOS = [
  { id: 'e1', nome: 'Caminhão Scania R450', tipo: 'Caminhão', placa: 'QRS-4521', status: 'Ativo', operadorId: 'u1' },
  { id: 'e2', nome: 'Ford Cargo 1932', tipo: 'Caminhão', placa: 'MNO-7834', status: 'Manutenção', operadorId: 'u2' },
  { id: 'e3', nome: 'Mercedes Atego 2430', tipo: 'Caminhão', placa: 'JKL-2290', status: 'Ativo', operadorId: 'u3' },
  { id: 'e4', nome: 'Volkswagen Constellation', tipo: 'Caminhão', placa: 'GHI-8812', status: 'Inativo', operadorId: null },
];

let EMPRESA_DOCS = [
  { id: 'emp1', titulo: 'Alvará de Funcionamento', categoria: 'Alvará', dataValidade: '2026-12-31', dataEmissao: '2026-01-02' },
  { id: 'emp2', titulo: 'Certificado ISO 9001', categoria: 'Certificação', dataValidade: '2025-09-15', dataEmissao: '2022-09-15' },
  { id: 'emp3', titulo: 'Licença Ambiental', categoria: 'Licença', dataValidade: '2027-03-20', dataEmissao: '2025-03-20' },
];

// ── STATE GLOBAL DO APP ──
let currentUser = null; 
let currentPage = 'dashboard';

// ── HELPERS GERAIS ──
function calcStatus(dataValidade) {
  const hoje = new Date(); hoje.setHours(0,0,0,0);
  const val = new Date(dataValidade + 'T00:00:00');
  const dias = Math.floor((val - hoje) / 86400000);
  if (dias < 0) return 'Vencido';
  if (dias <= 30) return 'A vencer';
  return 'Regular';
}

function formatarData(str) {
  if (!str) return '—';
  const [y,m,d] = str.split('-');
  return `${d}/${m}/${y}`;
}

function badgeStatus(s) {
  const map = { 'Regular': 'green', 'A vencer': 'amber', 'Vencido': 'red', 'Ativo': 'green', 'Inativo': 'gray', 'Manutenção': 'amber' };
  return `<span class="badge ${map[s]||'gray'}">${s}</span>`;
}

function iniciais(nome) { 
  return nome.split(' ').slice(0,2).map(w=>w[0]).join('').toUpperCase(); 
}

function nomeOperador(id) { 
  const u = COLABORADORES.find(c=>c.id===id); 
  return u ? u.nome : '—'; 
}

// ── CONTROLE DE LOGIN ──
function toggleSenha() {
  const inp = document.getElementById('senha-input');
  inp.type = inp.type === 'password' ? 'text' : 'password';
}

async function realizarLogin() {
  const mat = document.getElementById('matricula-input').value.trim();
  const sen = document.getElementById('senha-input').value.trim();
  const err = document.getElementById('login-error');
  err.style.display = 'none';

  if (!mat || !sen) { 
    err.textContent = 'Informe matrícula e senha.'; 
    err.style.display = 'block'; 
    return; 
  }

  if (USAR_API_REAL) {
    try {
      const response = await fetch(`${API_BASE_URL}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ matricula: mat, senha: sen })
      });
      if (!response.ok) throw new Error('Credenciais inválidas');
      currentUser = await response.json();
    } catch (e) {
      err.textContent = 'Erro ao autenticar. Verifique seus dados.';
      err.style.display = 'block';
      return;
    }
  } else {
    // Modo de Simulação Antigo
    const user = COLABORADORES.find(c => c.matricula === mat);
    if (!user) { err.textContent = 'Matrícula não encontrada.'; err.style.display = 'block'; return; }
    const senhaOk = (user.perfil === 'Administrador' && sen === 'admin123') || (user.perfil === 'Operador' && sen === '1234');
    if (!senhaOk) { err.textContent = 'Senha incorreta.'; err.style.display = 'block'; return; }
    if (user.status === 'Inativo') { err.textContent = 'Usuário inativo.'; err.style.display = 'block'; return; }
    currentUser = user;
  }

  document.getElementById('login-page').style.display = 'none';
  document.getElementById('app').style.display = 'flex';
  inicializarApp();
}

function logout() {
  currentUser = null;
  document.getElementById('login-page').style.display = 'flex';
  document.getElementById('app').style.display = 'none';
  document.getElementById('matricula-input').value = '';
  document.getElementById('senha-input').value = '';
}

// ── INICIALIZAÇÃO ──
async function inicializarApp() {
  document.getElementById('sidebar-name').textContent = currentUser.nome.split(' ')[0];
  document.getElementById('sidebar-role').textContent = currentUser.perfil;
  document.getElementById('sidebar-avatar').textContent = iniciais(currentUser.nome);

  // Sincroniza dados com o Banco se configurado
  if (USAR_API_REAL) {
    await atualizarDadosDoBanco();
  }

  renderizarNav();
  popularSelectsOperador();

  if (currentUser.perfil === 'Administrador') {
    carregarDashboard();
    navegarPara('dashboard');
  } else {
    carregarMeusDocs();
    carregarMinhaFrota();
    navegarPara('meus-docs');
  }
}

async function atualizarDadosDoBanco() {
  try {
    const [resColabs, resDocs, resEquip, resEmp] = await Promise.all([
      fetch(`${API_BASE_URL}/colaboradores`),
      fetch(`${API_BASE_URL}/documentos`),
      fetch(`${API_BASE_URL}/equipamentos`),
      fetch(`${API_BASE_URL}/empresa-docs`)
    ]);
    COLABORADORES = await resColabs.json();
    DOCUMENTOS = await resDocs.json();
    EQUIPAMENTOS = await resEquip.json();
    EMPRESA_DOCS = await resEmp.json();
  } catch (error) {
    showToast("Erro ao sincronizar com o banco de dados", "error");
  }
}

function renderizarNav() {
  const nav = document.getElementById('sidebar-nav');
  const isAdmin = currentUser.perfil === 'Administrador';

  const adminItems = [
    { id: 'dashboard', icon: '📊', label: 'Painel' },
    { id: 'colaboradores', icon: '👥', label: 'Colaboradores' },
    { id: 'frota', icon: '🚛', label: 'Frota & Equipamentos' },
    { id: 'documentos', icon: '📄', label: 'Documentos' },
    { id: 'empresa', icon: '🏢', label: 'Empresa' },
    { id: 'mapa', icon: '🗺️', label: 'Mapa da Frota' },
  ];
  const operItems = [
    { id: 'meus-docs', icon: '📄', label: 'Meus Documentos' },
    { id: 'minha-frota', icon: '🚛', label: 'Minha Frota' },
    { id: 'qrcode', icon: '📱', label: 'Meu QR Code' },
  ];
  const items = isAdmin ? adminItems : operItems;
  const common = [{ id: 'senha', icon: '🔑', label: 'Alterar Senha' }];

  let html = '';
  items.forEach(it => {
    html += `<div class="nav-item" id="nav-${it.id}" onclick="navegarPara('${it.id}')">
      <span class="nav-icon">${it.icon}</span> ${it.label}
    </div>`;
  });
  html += `<div class="nav-section-label">Conta</div>`;
  common.forEach(it => {
    html += `<div class="nav-item" id="nav-${it.id}" onclick="navegarPara('${it.id}')">
      <span class="nav-icon">${it.icon}</span> ${it.label}
    </div>`;
  });
  nav.innerHTML = html;
}

function navegarPara(id) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const page = document.getElementById('page-' + id);
  const nav = document.getElementById('nav-' + id);
  if (page) page.classList.add('active');
  if (nav) nav.classList.add('active');

  const titles = {
    'dashboard': 'Painel de Gestão', 'colaboradores': 'Colaboradores',
    'frota': 'Frota & Equipamentos', 'documentos': 'Documentos',
    'empresa': 'Empresa', 'mapa': 'Mapa da Frota',
    'meus-docs': 'Meus Documentos', 'minha-frota': 'Minha Frota',
    'qrcode': 'QR Code', 'senha': 'Alterar Senha'
  };
  document.getElementById('topbar-title').textContent = titles[id] || id;

  if (id === 'colaboradores') renderColabs(COLABORADORES);
  if (id === 'frota') renderEquips(EQUIPAMENTOS);
  if (id === 'documentos') renderDocs(DOCUMENTOS);
  if (id === 'empresa') renderEmpresa(EMPRESA_DOCS);
  if (id === 'qrcode') renderQR();
}

// ── DASHBOARD ──
function carregarDashboard() {
  const ativos = COLABORADORES.filter(c => c.perfil === 'Operador' && c.status === 'Ativo').length;
  const frotaAtiva = EQUIPAMENTOS.filter(e => e.status === 'Ativo').length;
  const manut = EQUIPAMENTOS.filter(e => e.status === 'Manutenção').length;
  const hoje = new Date(); hoje.setHours(0,0,0,0);
  const limite = new Date(hoje); limite.setDate(limite.getDate() + 30);
  const vencidos = DOCUMENTOS.filter(d => new Date(d.dataValidade + 'T00:00:00') < hoje);
  const avencer = DOCUMENTOS.filter(d => {
    const v = new Date(d.dataValidade + 'T00:00:00');
    return v >= hoje && v <= limite;
  });

  document.getElementById('stat-colaboradores').textContent = ativos;
  document.getElementById('stat-frota-ativa').textContent = frotaAtiva;
  document.getElementById('stat-manutencao').textContent = manut;
  document.getElementById('stat-pendencias').textContent = vencidos.length + avencer.length;

  const renderGrupo = (docs, cor) => {
    if (!docs.length) return '<div class="empty-state" style="padding:20px"><div class="empty-icon">✅</div><p>Nenhum documento</p></div>';
    return docs.map(d => {
      const u = COLABORADORES.find(c => c.id === d.userId);
      return `<div class="alert-item">
        <span>📄</span>
        <span class="alert-item-name">${d.titulo} • ${u ? u.nome.split(' ')[0] : '—'}</span>
        <span class="alert-item-date">${formatarData(d.dataValidade)}</span>
      </div>`;
    }).join('');
  };

  document.getElementById('dash-vencidos').innerHTML = vencidos.length
    ? `<div class="alert-group red">
        <div class="alert-group-header">
          <span class="alert-group-icon">🔴</span>
          <div><div class="alert-group-title">Documentos vencidos</div><div class="alert-group-sub">Requerem ação imediata</div></div>
          <span class="alert-count">${vencidos.length}</span>
        </div>${renderGrupo(vencidos,'red')}
      </div>`
    : `<div class="alert-group" style="background:#F0FFF4;border-color:#C6F6D5"><div class="alert-group-header"><span class="alert-group-icon">✅</span><div class="alert-group-title" style="color:#276749">Tudo em dia</div></div></div>`;

  document.getElementById('dash-avencer').innerHTML = avencer.length
    ? `<div class="alert-group amber">
        <div class="alert-group-header">
          <span class="alert-group-icon">🟡</span>
          <div><div class="alert-group-title">A vencer em 30 dias</div><div class="alert-group-sub">Renove antes do vencimento</div></div>
          <span class="alert-count">${avencer.length}</span>
        </div>${renderGrupo(avencer,'amber')}
      </div>`
    : `<div class="alert-group" style="background:#F0FFF4;border-color:#C6F6D5"><div class="alert-group-header"><span class="alert-group-icon">✅</span><div class="alert-group-title" style="color:#276749">Tudo em dia</div></div></div>`;
}

// ── SEÇÃO COLABORADORES ──
let collabFiltro = '', collabStatusFiltro = '';
function renderColabs(lista) {
  const el = document.getElementById('collab-grid');
  let filtrado = lista;
  if (collabFiltro) filtrado = filtrado.filter(c => c.perfil === collabFiltro);
  if (collabStatusFiltro) filtrado = filtrado.filter(c => c.status === collabStatusFiltro);
  if (!filtrado.length) { el.innerHTML = '<div class="empty-state"><div class="empty-icon">👥</div><p>Nenhum colaborador encontrado</p></div>'; return; }
  el.innerHTML = filtrado.map(c => `
    <div class="collab-card" onclick="editarColab('${c.id}')">
      <div class="collab-avatar">${iniciais(c.nome)}</div>
      <div class="collab-name">${c.nome}</div>
      <div class="collab-info">Mat. ${c.matricula} · ${c.perfil}</div>
      <div style="margin-top:10px">${badgeStatus(c.status)}</div>
    </div>
  `).join('');
}
function filtrarColabs(v) { collabFiltro = v; renderColabs(COLABORADORES); }
function filtrarColabsStatus(v) { collabStatusFiltro = v; renderColabs(COLABORADORES); }

let editandoColabId = null;
function abrirModalColab() {
  editandoColabId = null;
  document.getElementById('modal-colab-title').textContent = 'Novo Colaborador';
  ['colab-nome','colab-matricula','colab-senha'].forEach(id => document.getElementById(id).value = '');
  document.getElementById('modal-colab').classList.add('open');
}
function editarColab(id) {
  const c = COLABORADORES.find(x => x.id === id);
  if (!c) return;
  editandoColabId = id;
  document.getElementById('modal-colab-title').textContent = 'Editar Colaborador';
  document.getElementById('colab-nome').value = c.nome;
  document.getElementById('colab-matricula').value = c.matricula;
  document.getElementById('colab-perfil').value = c.perfil;
  document.getElementById('colab-status').value = c.status;
  document.getElementById('modal-colab').classList.add('open');
}

async function salvarColab() {
  const nome = document.getElementById('colab-nome').value.trim();
  const matricula = document.getElementById('colab-matricula').value;
  const perfil = document.getElementById('colab-perfil').value;
  const status = document.getElementById('colab-status').value;

  if (!nome) { showToast('Informe o nome.', 'error'); return; }

  const payLoad = { nome, matricula, perfil, status };

  if (USAR_API_REAL) {
    const url = editandoColabId ? `${API_BASE_URL}/colaboradores/${editandoColabId}` : `${API_BASE_URL}/colaboradores`;
    const method = editandoColabId ? 'PUT' : 'POST';
    await fetch(url, {
      method, headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payLoad)
    });
    await atualizarDadosDoBanco();
  } else {
    // Sincronização Local antiga
    if (editandoColabId) {
      const c = COLABORADORES.find(x => x.id === editandoColabId);
      Object.assign(c, payLoad);
    } else {
      COLABORADORES.push({ id: 'u' + Date.now(), ...payLoad });
    }
  }

  showToast('Dados salvos com sucesso!', 'success');
  fecharModal('modal-colab');
  renderColabs(COLABORADORES);
  popularSelectsOperador();
}

// ── SEÇÃO DOCUMENTOS ──
function popularSelectsOperador() {
  const ops = COLABORADORES.filter(c => c.perfil === 'Operador');
  ['filtro-doc-usuario','doc-operador','equip-operador'].forEach(id => {
    const sel = document.getElementById(id);
    if (!sel) return;
    const first = sel.options[0];
    sel.innerHTML = '';
    sel.appendChild(first);
    ops.forEach(o => {
      const opt = document.createElement('option');
      opt.value = o.id; opt.textContent = o.nome;
      sel.appendChild(opt);
    });
  });
}

let docFiltroUser = '', docFiltroTipo = '', docFiltroStatus = '';
function renderDocs(lista) {
  let filtrado = lista;
  if (docFiltroUser) filtrado = filtrado.filter(d => d.userId === docFiltroUser);
  if (docFiltroTipo) filtrado = filtrado.filter(d => d.titulo === docFiltroTipo);
  if (docFiltroStatus) filtrado = filtrado.filter(d => calcStatus(d.dataValidade) === docFiltroStatus);
  const tbody = document.getElementById('docs-tbody');
  if (!filtrado.length) { tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:var(--text-muted);padding:32px">Nenhum documento encontrado</td></tr>'; return; }
  tbody.innerHTML = filtrado.map(d => {
    const status = calcStatus(d.dataValidade);
    const u = COLABORADORES.find(c => c.id === d.userId);
    return `<tr>
      <td><strong>${d.titulo}</strong></td>
      <td>${u ? u.nome : '—'}</td>
      <td>${formatarData(d.dataValidade)}</td>
      <td>${badgeStatus(status)}</td>
      <td>
        <button class="btn btn-sm btn-outline" onclick="editarDoc('${d.id}')">✏️ Editar</button>
        <button class="btn btn-sm btn-danger" onclick="excluirDoc('${d.id}')" style="margin-left:6px">🗑️</button>
      </td>
    </tr>`;
  }).join('');
}

function filtrarDocs() {
  docFiltroUser = document.getElementById('filtro-doc-usuario').value;
  docFiltroTipo = document.getElementById('filtro-doc-tipo').value;
  docFiltroStatus = document.getElementById('filtro-doc-status').value;
  renderDocs(DOCUMENTOS);
}

function abrirModalDoc() { document.getElementById('modal-doc').classList.add('open'); }

async function salvarDoc() {
  const tipo = document.getElementById('doc-tipo').value;
  const userId = document.getElementById('doc-operador').value;
  const validade = document.getElementById('doc-validade').value;
  const emissao = document.getElementById('doc-emissao').value;

  if (!userId || !validade) { showToast('Preencha operador e validade.', 'error'); return; }

  const payload = { titulo: tipo, userId, dataValidade: validade, dataEmissao: emissao };

  if (USAR_API_REAL) {
    await fetch(`${API_BASE_URL}/documentos`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    await atualizarDadosDoBanco();
  } else {
    DOCUMENTOS.push({ id: 'd' + Date.now(), ...payload });
  }

  fecharModal('modal-doc');
  renderDocs(DOCUMENTOS);
  carregarDashboard();
  showToast('Documento adicionado!', 'success');
}

async function excluirDoc(id) {
  if (USAR_API_REAL) {
    await fetch(`${API_BASE_URL}/documentos/${id}`, { method: 'DELETE' });
    await atualizarDadosDoBanco();
  } else {
    const i = DOCUMENTOS.findIndex(d => d.id === id);
    if (i > -1) DOCUMENTOS.splice(i, 1);
  }
  renderDocs(DOCUMENTOS); 
  carregarDashboard();
  showToast('Documento removido.', 'success');
}

// ── SEÇÃO EQUIPAMENTOS ──
let equipFiltro = '';
function renderEquips(lista) {
  let filtrado = lista;
  if (equipFiltro) filtrado = filtrado.filter(e => e.status === equipFiltro);
  const el = document.getElementById('equip-grid');
  if (!filtrado.length) { el.innerHTML = '<div class="empty-state"><div class="empty-icon">🚛</div><p>Nenhum equipamento encontrado</p></div>'; return; }
  el.innerHTML = filtrado.map(e => `
    <div class="equip-card" onclick="editarEquip('${e.id}')">
      <div class="equip-card-header">
        <div class="equip-icon">🚛</div>
        <div>
          <div class="equip-name">${e.nome}</div>
          <div class="equip-meta">${e.tipo} · ${e.placa || '—'}</div>
        </div>
      </div>
      <div class="equip-footer">
        ${badgeStatus(e.status)}
        <span style="font-size:12px;color:var(--text-muted)">${e.operadorId ? nomeOperador(e.operadorId).split(' ')[0] : 'Sem operador'}</span>
      </div>
    </div>
  `).join('');
}

function filtrarEquips(v) { equipFiltro = v; renderEquips(EQUIPAMENTOS); }
let editandoEquipId = null;

function abrirModalEquip() {
  editandoEquipId = null;
  ['equip-nome','equip-placa'].forEach(id => document.getElementById(id).value = '');
  document.getElementById('modal-equip').classList.add('open');
}

function editarEquip(id) {
  const e = EQUIPAMENTOS.find(x => x.id === id);
  if (!e) return;
  editandoEquipId = id;
  document.getElementById('equip-nome').value = e.nome;
  document.getElementById('equip-tipo').value = e.tipo;
  document.getElementById('equip-status').value = e.status;
  document.getElementById('equip-placa').value = e.placa || '';
  document.getElementById('equip-operador').value = e.operadorId || '';
  document.getElementById('modal-equip').classList.add('open');
}

async function salvarEquip() {
  const nome = document.getElementById('equip-nome').value.trim();
  const tipo = document.getElementById('equip-tipo').value;
  const status = document.getElementById('equip-status').value;
  const placa = document.getElementById('equip-placa').value;
  const operadorId = document.getElementById('equip-operador').value || null;

  if (!nome) { showToast('Informe o nome.', 'error'); return; }

  const payload = { nome, tipo, status, placa, operadorId };

  if (USAR_API_REAL) {
    const url = editandoEquipId ? `${API_BASE_URL}/equipamentos/${editandoEquipId}` : `${API_BASE_URL}/equipamentos`;
    const method = editandoEquipId ? 'PUT' : 'POST';
    await fetch(url, {
      method, headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    await atualizarDadosDoBanco();
  } else {
    if (editandoEquipId) {
      const e = EQUIPAMENTOS.find(x => x.id === editandoEquipId);
      Object.assign(e, payload);
    } else {
      EQUIPAMENTOS.push({ id: 'e'+Date.now(), ...payload });
    }
  }

  fecharModal('modal-equip');
  renderEquips(EQUIPAMENTOS);
  carregarDashboard();
  showToast('Equipamento salvo!', 'success');
}

// ── SEÇÃO DOCUMENTOS DA EMPRESA ──
function renderEmpresa(lista) {
  const tbody = document.getElementById('empresa-tbody');
  tbody.innerHTML = lista.map(d => {
    const status = calcStatus(d.dataValidade);
    return `<tr>
      <td><strong>${d.titulo}</strong></td>
      <td><span class="badge blue">${d.categoria}</span></td>
      <td>${formatarData(d.dataValidade)}</td>
      <td>${badgeStatus(status)}</td>
      <td><button class="btn btn-sm btn-outline">📎 Ver</button></td>
    </tr>`;
  }).join('');
}

function abrirModalEmpresa() { document.getElementById('modal-empresa').classList.add('open'); }

async function salvarEmpresa() {
  const titulo = document.getElementById('emp-titulo').value.trim();
  const categoria = document.getElementById('emp-categoria').value;
  const validade = document.getElementById('emp-validade').value;
  const emissao = document.getElementById('emp-emissao').value;

  if (!titulo) { showToast('Informe o título.', 'error'); return; }

  const payload = { titulo, categoria, dataValidade: validade, dataEmissao: emissao };

  if (USAR_API_REAL) {
    await fetch(`${API_BASE_URL}/empresa-docs`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    await atualizarDadosDoBanco();
  } else {
    EMPRESA_DOCS.push({ id: 'emp'+Date.now(), ...payload });
  }

  fecharModal('modal-empresa');
  renderEmpresa(EMPRESA_DOCS);
  showToast('Documento adicionado!', 'success');
}

// ── VISUALIZAÇÃO DO OPERADOR ──
function carregarMeusDocs() {
  const meusDocs = DOCUMENTOS.filter(d => d.userId === currentUser.id);
  const tbody = document.getElementById('meus-docs-tbody');
  if (!meusDocs.length) { tbody.innerHTML = '<tr><td colspan="4" style="text-align:center;padding:32px;color:var(--text-muted)">Nenhum documento cadastrado</td></tr>'; return; }
  tbody.innerHTML = meusDocs.map(d => `<tr>
    <td><strong>${d.titulo}</strong></td>
    <td>${formatarData(d.dataValidade)}</td>
    <td>${badgeStatus(calcStatus(d.dataValidade))}</td>
    <td><button class="btn btn-sm btn-outline">📎 Ver</button></td>
  </tr>`).join('');
}

function carregarMinhaFrota() {
  const equips = EQUIPAMENTOS.filter(e => e.operadorId === currentUser.id);
  const el = document.getElementById('minha-frota-grid');
  if (!equips.length) { el.innerHTML = '<div class="empty-state"><div class="empty-icon">🚛</div><p>Nenhum equipamento atribuído</p></div>'; return; }
  el.innerHTML = equips.map(e => `<div class="equip-card">
    <div class="equip-card-header"><div class="equip-icon">🚛</div><div><div class="equip-name">${e.nome}</div><div class="equip-meta">${e.tipo} · ${e.placa}</div></div></div>
    <div class="equip-footer">${badgeStatus(e.status)}</div>
  </div>`).join('');
}

function renderQR() {
  document.getElementById('qr-nome').textContent = currentUser.nome;
  document.getElementById('qr-mat').textContent = 'Matrícula: ' + currentUser.matricula;
}

// ── BUSCA GLOBAL (PLACEHOLDER) ──
function buscarGlobal(q) {
  // Implementação futura de busca no BD
}

// ── SISTEMA DE MODAIS GERAIS ──
function fecharModal(id) { document.getElementById(id).classList.remove('open'); }
document.querySelectorAll('.modal-overlay').forEach(m => {
  m.addEventListener('click', e => { if (e.target === m) fecharModal(m.id); });
});

// ── TOAST MESSAGES ──
let toastTimer;
function showToast(msg, type = '') {
  const t = document.getElementById('toast');
  t.textContent = (type === 'success' ? '✅ ' : type === 'error' ? '❌ ' : '') + msg;
  t.className = 'toast show' + (type ? ' ' + type : '');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.classList.remove('show'); }, 3000);
}

// ── MONITORAMENTO DE TECLADO ──
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') document.querySelectorAll('.modal-overlay.open').forEach(m => m.classList.remove('open'));
  if (e.key === 'Enter' && document.getElementById('login-page').style.display !== 'none') realizarLogin();
});