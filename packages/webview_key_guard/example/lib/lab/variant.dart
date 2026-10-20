enum LabVariant {
  currentPackage('P', 'Актуальный пакет'),
  baseline('0', 'Без фикса'),
  enterOnly('A', 'Только Cmd+Enter'),
  routing('B', 'Маршрутизация'),
  keyDownRouting('B1', 'Только keyDown'),
  guardedKeyDownRouting('B2', 'keyDown + защита Flutter'),
  commandBoundaryRouting('B3', 'B2 + граница команд'),
  identity('C', 'Защита от дубликата'),
  fullIdentity('C2', 'Защита на всех границах'),
  nativeWindow('D', 'Нативное окно'),
  javascript('E', 'JavaScript');

  const LabVariant(this.id, this.label);
  final String id;
  final String label;
}
