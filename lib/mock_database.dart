class AppUser {
  String nome;
  String matricula;
  String senha;
  String cargo;
  String perfil;
  String status;
  bool precisaTrocarSenha;

  AppUser({
    required this.nome,
    required this.matricula,
    required this.senha,
    required this.cargo,
    required this.perfil,
    required this.status,
    required this.precisaTrocarSenha,
  });
}

class MockDatabase {
  static List<AppUser> usuarios = [
    AppUser(
      nome: 'Carlos Silva',
      matricula: '111',
      senha: '123',
      cargo: 'Operador de Guindaste',
      perfil: 'Operador',
      status: 'Ativo',
      precisaTrocarSenha: false,
    ),
    AppUser(
      nome: 'Mariana Souza',
      matricula: '999',
      senha: '123',
      cargo: 'Administradora',
      perfil: 'Administrador',
      status: 'Ativo',
      precisaTrocarSenha: false,
    ),
  ];

  static AppUser? login(String matricula, String senha) {
    try {
      return usuarios.firstWhere(
        (user) =>
            user.matricula == matricula &&
            user.senha == senha &&
            user.status == 'Ativo',
      );
    } catch (_) {
      return null;
    }
  }
}