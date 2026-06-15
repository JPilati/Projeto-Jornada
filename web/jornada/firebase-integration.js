const jornadaFirebaseConfig = {
  apiKey: 'AIzaSyD3mIXhCEeuELLjLyFbaToEANn7QN9DmO4',
  authDomain: 'guindastes-ribasdb.firebaseapp.com',
  projectId: 'guindastes-ribasdb',
  storageBucket: 'guindastes-ribasdb.firebasestorage.app',
  messagingSenderId: '395359559014',
  appId: '1:395359559014:web:f62e16024af59da7a7fca7',
  measurementId: 'G-ZN0FPERPKM'
};

const jornadaApp = firebase.apps.length
  ? firebase.app()
  : firebase.initializeApp(jornadaFirebaseConfig);
const jornadaAuth = firebase.auth(jornadaApp);
const jornadaDb = firebase.firestore(jornadaApp);

let jornadaEditandoDocId = null;

function jornadaEmailPorMatricula(matricula) {
  return `${matricula.trim()}@app.com`;
}

function jornadaIsoDate(value) {
  if (!value) return '';
  if (typeof value === 'string') return value.split('T')[0];
  if (value.toDate) return value.toDate().toISOString().split('T')[0];
  if (value instanceof Date) return value.toISOString().split('T')[0];
  return String(value).split('T')[0];
}

function jornadaTimestamp() {
  return firebase.firestore.FieldValue.serverTimestamp();
}

function jornadaDateTimestamp(isoDate) {
  return firebase.firestore.Timestamp.fromDate(new Date(`${isoDate}T00:00:00`));
}

function jornadaMapColaborador(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    nome: data.nome || 'Sem nome',
    matricula: data.matricula || '',
    cargo: data.cargo || '',
    perfil: data.perfil || 'Operador',
    status: data.status || 'Ativo',
    precisaTrocarSenha: data.precisaTrocarSenha === true,
    ...data
  };
}

function jornadaMapDocumento(doc) {
  const data = doc.data();
  const usuarioId = data.usuarioId || data.userId || null;
  const dataValidade = jornadaIsoDate(data.dataValidade);
  return {
    id: doc.id,
    titulo: data.titulo || data.categoria || 'Documento',
    categoria: data.categoria || data.titulo || 'Documento',
    userId: usuarioId,
    usuarioId,
    equipamentoId: data.equipamentoId || null,
    tipo: data.tipo || (data.equipamentoId ? 'equipamento' : 'operador'),
    dataValidade,
    dataEmissao: jornadaIsoDate(data.dataEmissao),
    status: data.status || calcStatus(dataValidade),
    arquivoUrl: data.arquivoUrl || data.arquivo_url || '',
    ...data
  };
}

function jornadaMapEquipamento(doc) {
  const data = doc.data();
  const operadoresPermitidos = Array.isArray(data.operadoresPermitidos)
    ? data.operadoresPermitidos
    : [];
  return {
    id: doc.id,
    nome: data.nome || 'Equipamento',
    tipo: data.tipo || 'Sem tipo',
    placa: data.placa || '',
    capacidade: data.capacidade || '',
    status: data.status || 'Ativo',
    operadorId: data.operadorId || operadoresPermitidos[0] || null,
    operadoresPermitidos,
    ...data
  };
}

function jornadaMapEmpresaDoc(doc) {
  const data = doc.data();
  const dataValidade = jornadaIsoDate(data.dataValidade || data.data_vencimento);
  return {
    id: doc.id,
    titulo: data.titulo || data.nome || 'Documento',
    categoria: data.categoria || data.tipo || 'Geral',
    dataValidade,
    dataEmissao: jornadaIsoDate(data.dataEmissao || data.data_emissao),
    status: data.status || calcStatus(dataValidade),
    arquivoUrl: data.arquivoUrl || data.arquivo_url || '',
    ...data
  };
}

realizarLogin = async function realizarLoginFirebase() {
  const matricula = document.getElementById('matricula-input').value.trim();
  const senha = document.getElementById('senha-input').value.trim();
  const erro = document.getElementById('login-error');
  erro.style.display = 'none';

  if (!matricula || !senha) {
    erro.textContent = 'Informe matricula e senha.';
    erro.style.display = 'block';
    return;
  }

  try {
    const credential = await jornadaAuth.signInWithEmailAndPassword(
      jornadaEmailPorMatricula(matricula),
      senha
    );
    const perfilDoc = await jornadaDb
      .collection('users')
      .doc(credential.user.uid)
      .get();

    if (!perfilDoc.exists) throw new Error('Perfil nao encontrado.');

    const perfil = jornadaMapColaborador(perfilDoc);
    if (perfil.status === 'Inativo') {
      await jornadaAuth.signOut();
      throw new Error('Usuario inativo.');
    }

    if (perfil.perfil !== 'Administrador') {
      await jornadaAuth.signOut();
      throw new Error('Acesso permitido apenas para administradores.');
    }

    currentUser = perfil;
    document.getElementById('login-page').style.display = 'none';
    document.getElementById('app').style.display = 'flex';
    await inicializarApp();
  } catch (error) {
    erro.textContent = error.message || 'Erro ao autenticar.';
    erro.style.display = 'block';
  }
};

logout = async function logoutFirebase() {
  await jornadaAuth.signOut();
  currentUser = null;
  document.getElementById('login-page').style.display = 'flex';
  document.getElementById('app').style.display = 'none';
  document.getElementById('matricula-input').value = '';
  document.getElementById('senha-input').value = '';
};

atualizarDadosDoBanco = async function atualizarDadosFirebase() {
  const [colabs, docs, equips, empresa] = await Promise.all([
    jornadaDb.collection('users').get(),
    jornadaDb.collection('documentos').get(),
    jornadaDb.collection('equipamentos').get(),
    jornadaDb.collection('documentos_empresa').get()
  ]);

  COLABORADORES = colabs.docs.map(jornadaMapColaborador)
    .sort((a, b) => (a.nome || '').localeCompare(b.nome || ''));
  DOCUMENTOS = docs.docs.map(jornadaMapDocumento);
  EQUIPAMENTOS = equips.docs.map(jornadaMapEquipamento)
    .sort((a, b) => (a.nome || '').localeCompare(b.nome || ''));
  EMPRESA_DOCS = empresa.docs.map(jornadaMapEmpresaDoc);
};

abrirModalDoc = function abrirModalDocFirebase() {
  jornadaEditandoDocId = null;
  ['doc-emissao', 'doc-validade'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.value = '';
  });
  document.getElementById('doc-operador').value = '';
  document.getElementById('modal-doc').classList.add('open');
};

editarDoc = function editarDocFirebase(id) {
  const doc = DOCUMENTOS.find(item => item.id === id);
  if (!doc) return;

  jornadaEditandoDocId = id;
  document.getElementById('doc-tipo').value = doc.titulo || doc.categoria || 'ASO';
  document.getElementById('doc-operador').value = doc.usuarioId || doc.userId || '';
  document.getElementById('doc-emissao').value = doc.dataEmissao || '';
  document.getElementById('doc-validade').value = doc.dataValidade || '';
  document.getElementById('modal-doc').classList.add('open');
};

salvarColab = async function salvarColabFirebase() {
  const nome = document.getElementById('colab-nome').value.trim();
  const matricula = document.getElementById('colab-matricula').value.trim();
  const senha = document.getElementById('colab-senha').value.trim();
  const perfil = document.getElementById('colab-perfil').value;
  const status = document.getElementById('colab-status').value;
  const payload = { nome, matricula, perfil, status };

  if (!nome || !matricula) {
    showToast('Preencha nome e matricula.', 'error');
    return;
  }

  try {
    if (editandoColabId) {
      await jornadaDb.collection('users').doc(editandoColabId).update(payload);
    } else {
      if (senha.length < 6) {
        showToast('Informe uma senha inicial com pelo menos 6 caracteres.', 'error');
        return;
      }

      const secondaryApp = firebase.initializeApp(
        jornadaFirebaseConfig,
        `secondary-${Date.now()}`
      );
      const secondaryAuth = firebase.auth(secondaryApp);
      const credential = await secondaryAuth.createUserWithEmailAndPassword(
        jornadaEmailPorMatricula(matricula),
        senha
      );

      await jornadaDb.collection('users').doc(credential.user.uid).set({
        ...payload,
        precisaTrocarSenha: true,
        createdAt: jornadaTimestamp()
      });
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }

    await atualizarDadosDoBanco();
    renderColabs(COLABORADORES);
    popularSelectsOperador();
    carregarDashboard();
    fecharModal('modal-colab');
    showToast('Colaborador salvo com sucesso!', 'success');
  } catch (error) {
    showToast(error.message || 'Erro ao salvar colaborador.', 'error');
  }
};

salvarDoc = async function salvarDocFirebase() {
  const titulo = document.getElementById('doc-tipo').value;
  const usuarioId = document.getElementById('doc-operador').value;
  const validade = document.getElementById('doc-validade').value;
  const emissao = document.getElementById('doc-emissao').value;

  if (!usuarioId || !validade) {
    showToast('Preencha operador e validade.', 'error');
    return;
  }

  const payload = {
    usuarioId,
    equipamentoId: null,
    tipo: 'operador',
    titulo,
    categoria: titulo,
    dataValidade: validade,
    dataEmissao: emissao || null,
    status: calcStatus(validade),
    visivelOperador: true,
    updatedAt: jornadaTimestamp()
  };

  try {
    if (jornadaEditandoDocId) {
      await jornadaDb.collection('documentos').doc(jornadaEditandoDocId).update(payload);
    } else {
      await jornadaDb.collection('documentos').add({
        ...payload,
        createdAt: jornadaTimestamp()
      });
    }

    jornadaEditandoDocId = null;
    await atualizarDadosDoBanco();
    renderDocs(DOCUMENTOS);
    carregarDashboard();
    fecharModal('modal-doc');
    showToast('Documento salvo com sucesso!', 'success');
  } catch (error) {
    showToast(error.message || 'Erro ao salvar documento.', 'error');
  }
};

excluirDoc = async function excluirDocFirebase(id) {
  try {
    await jornadaDb.collection('documentos').doc(id).delete();
    await atualizarDadosDoBanco();
    renderDocs(DOCUMENTOS);
    carregarDashboard();
    showToast('Documento removido.', 'success');
  } catch (error) {
    showToast(error.message || 'Erro ao remover documento.', 'error');
  }
};

salvarEquip = async function salvarEquipFirebase() {
  const nome = document.getElementById('equip-nome').value.trim();
  const tipo = document.getElementById('equip-tipo').value;
  const status = document.getElementById('equip-status').value;
  const placa = document.getElementById('equip-placa').value.trim();
  const operadorId = document.getElementById('equip-operador').value || null;

  if (!nome) {
    showToast('Informe o nome.', 'error');
    return;
  }

  const payload = {
    nome,
    tipo,
    status,
    placa,
    operadorId,
    operadoresPermitidos: operadorId ? [operadorId] : [],
    updatedAt: jornadaTimestamp()
  };

  try {
    if (editandoEquipId) {
      await jornadaDb.collection('equipamentos').doc(editandoEquipId).update(payload);
    } else {
      await jornadaDb.collection('equipamentos').add({
        ...payload,
        createdAt: jornadaTimestamp()
      });
    }

    await atualizarDadosDoBanco();
    renderEquips(EQUIPAMENTOS);
    carregarDashboard();
    fecharModal('modal-equip');
    showToast('Equipamento salvo!', 'success');
  } catch (error) {
    showToast(error.message || 'Erro ao salvar equipamento.', 'error');
  }
};

salvarEmpresa = async function salvarEmpresaFirebase() {
  const titulo = document.getElementById('emp-titulo').value.trim();
  const categoria = document.getElementById('emp-categoria').value;
  const validade = document.getElementById('emp-validade').value;
  const emissao = document.getElementById('emp-emissao').value;

  if (!titulo || !validade || !emissao) {
    showToast('Preencha titulo, emissao e validade.', 'error');
    return;
  }

  try {
    await jornadaDb.collection('documentos_empresa').add({
      nome: titulo,
      tipo: categoria,
      equipamento: 'Empresa',
      data_emissao: jornadaDateTimestamp(emissao),
      data_vencimento: jornadaDateTimestamp(validade),
      status: calcStatus(validade),
      observacao: '',
      created_at: jornadaTimestamp()
    });

    await atualizarDadosDoBanco();
    renderEmpresa(EMPRESA_DOCS);
    fecharModal('modal-empresa');
    showToast('Documento adicionado!', 'success');
  } catch (error) {
    showToast(error.message || 'Erro ao salvar documento da empresa.', 'error');
  }
};

alterarSenha = async function alterarSenhaFirebase() {
  const senhaAtual = document.getElementById('senha-atual-input').value.trim();
  const novaSenha = document.getElementById('nova-senha-input').value.trim();
  const confirmarSenha = document
    .getElementById('confirmar-senha-input')
    .value
    .trim();

  if (!senhaAtual || !novaSenha || !confirmarSenha) {
    showToast('Preencha todos os campos de senha.', 'error');
    return;
  }

  if (novaSenha.length < 6) {
    showToast('A nova senha deve ter pelo menos 6 caracteres.', 'error');
    return;
  }

  if (novaSenha !== confirmarSenha) {
    showToast('A confirmação não confere com a nova senha.', 'error');
    return;
  }

  const user = jornadaAuth.currentUser;
  if (!user || !currentUser) {
    showToast('Sessão expirada. Faça login novamente.', 'error');
    return;
  }

  try {
    const credential = firebase.auth.EmailAuthProvider.credential(
      jornadaEmailPorMatricula(currentUser.matricula),
      senhaAtual
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(novaSenha);
    await jornadaDb.collection('users').doc(user.uid).update({
      precisaTrocarSenha: false,
      updatedAt: jornadaTimestamp()
    });

    currentUser.precisaTrocarSenha = false;
    document.getElementById('senha-atual-input').value = '';
    document.getElementById('nova-senha-input').value = '';
    document.getElementById('confirmar-senha-input').value = '';
    showToast('Senha alterada com sucesso!', 'success');
  } catch (error) {
    const message = error.code === 'auth/wrong-password'
      ? 'Senha atual incorreta.'
      : error.message || 'Erro ao alterar senha.';
    showToast(message, 'error');
  }
};
