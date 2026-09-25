export function formatSubjectName(value: string): string {
  const source: string = value.trim();
  if (source.length === 0) { return source; }

  const normalized: string = source.replace(/\s|_|-/g, '').toLowerCase();
  switch (normalized) {
    case 'collegeenglish': return '大学英语';
    case 'english': return '英语';
    case 'cet4': return '大学英语四级';
    case 'cet6': return '大学英语六级';
    case 'linearalgebra': return '线性代数';
    case 'advancedmath':
    case 'highermathematics': return '高等数学';
    case 'calculus': return '微积分';
    case 'datastructure':
    case 'datastructures': return '数据结构';
    case 'operatingsystem':
    case 'operatingsystems': return '操作系统';
    case 'computernetwork':
    case 'computernetworks': return '计算机网络';
    case 'discretemath':
    case 'discretemathematics': return '离散数学';
    case 'probabilitystatistics':
    case 'probabilityandstatistics': return '概率论与数理统计';
    case 'programming': return '程序设计';
    case 'softwareengineering': return '软件工程';
    case 'database':
    case 'databasesystems': return '数据库系统';
    case 'computerorganization': return '计算机组成原理';
    case 'collegephysics': return '大学物理';
    case 'physics': return '物理';
    case 'chemistry': return '化学';
    case 'artificialintelligence': return '人工智能';
    case 'machinelearning': return '机器学习';
    default: break;
  }

  const keys: string[] = ['CollegeEnglish', 'LinearAlgebra', 'AdvancedMath', 'HigherMathematics',
    'DataStructures', 'DataStructure', 'OperatingSystems', 'OperatingSystem', 'ComputerNetworks',
    'ComputerNetwork', 'DiscreteMathematics', 'DiscreteMath', 'ProbabilityAndStatistics',
    'ProbabilityStatistics', 'SoftwareEngineering', 'DatabaseSystems', 'ComputerOrganization',
    'CollegePhysics', 'ArtificialIntelligence', 'MachineLearning'];
  const names: string[] = ['大学英语', '线性代数', '高等数学', '高等数学', '数据结构', '数据结构',
    '操作系统', '操作系统', '计算机网络', '计算机网络', '离散数学', '离散数学', '概率论与数理统计',
    '概率论与数理统计', '软件工程', '数据库系统', '计算机组成原理', '大学物理', '人工智能', '机器学习'];
  let display: string = source;
  keys.forEach((key: string, index: number) => {
    display = display.split(key).join(names[index]);
  });
  return display;
}
