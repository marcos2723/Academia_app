import 'package:url_launcher/url_launcher.dart';

/// Monta e abre um link "wa.me" com uma mensagem pronta no WhatsApp.
///
/// Isso NÃO envia a mensagem sozinho — abre o WhatsApp (app ou web) já com
/// o texto preenchido, e quem está usando o app só precisa tocar em
/// enviar. Enviar automaticamente, sem esse toque, exigiria uma conta
/// comercial aprovada na API oficial do WhatsApp (Meta Cloud API ou
/// Twilio), o que não é viável configurar aqui.
class WhatsAppService {
  /// Formata um telefone brasileiro para o padrão internacional exigido
  /// pelo wa.me (só dígitos, com código do país). Aceita números com ou
  /// sem "55", com ou sem DDD já formatado.
  static String _normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('55')) return digits;
    return '55$digits';
  }

  static Uri buildLink({required String phone, required String message}) {
    final normalized = _normalizePhone(phone);
    return Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent(message)}');
  }

  /// Retorna false se não foi possível abrir (ex: número inválido ou
  /// nenhum app/navegador disponível para o link).
  static Future<bool> sendCredentials({
    required String phone,
    required String studentName,
    required String email,
    required String temporaryPassword,
  }) async {
    final message = 'Olá, $studentName! 👋\n\n'
        'Seu acesso ao app de acompanhamento da academia foi criado.\n\n'
        'E-mail: $email\n'
        'Senha provisória: $temporaryPassword\n\n'
        'Faça login com esses dados e, assim que entrar, o app vai pedir '
        'para você criar uma senha nova. Guarde essa mensagem só até fazer '
        'o primeiro acesso.';
    final uri = buildLink(phone: phone, message: message);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Convite pra marcar uma nova avaliação, usado com alunos que estão há
  /// muito tempo sem passar por uma (ou nunca passaram).
  static Future<bool> inviteForEvaluation({
    required String phone,
    required String studentName,
    int? daysSinceLastEvaluation,
  }) async {
    final referencia = daysSinceLastEvaluation == null
        ? 'ainda não fizemos sua primeira avaliação física'
        : 'já faz $daysSinceLastEvaluation dias desde sua última avaliação física';
    final message = 'Olá, $studentName! 👋\n\n'
        'Notei que $referencia. Que tal agendarmos uma nova avaliação para '
        'acompanhar sua evolução? Me avisa qual dia e horário funcionam '
        'melhor pra você.';
    final uri = buildLink(phone: phone, message: message);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Mensagem de incentivo para quem está registrando pouco ou parou.
  static Future<bool> encourageRegistration({
    required String phone,
    required String studentName,
    double? percent,
    int? daysSilent,
  }) async {
    final motivo = daysSilent == null
        ? 'ainda não vi nenhum registro seu no app'
        : daysSilent >= 7
            ? 'faz $daysSilent dias que não vejo um registro seu no app'
            : 'vi que sua adesão recente está em ${percent?.round() ?? 0}%';
    final message = 'Olá, $studentName! 👋\n\n'
        'Passando para dizer que $motivo. Está tudo bem? Se precisar ajustar '
        'seu treino ou sua dieta, é só me avisar. Lembre de registrar no app '
        'o que você fez — isso me ajuda a acompanhar sua evolução!';
    final uri = buildLink(phone: phone, message: message);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
