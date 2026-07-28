export const DEFAULT_ROW_COUNTER_NAME = 'Vueltas';
export const DEFAULT_STITCH_COUNTER_NAME = 'Puntos';
export const MAX_HISTORY_ENTRIES = 100;

export const PROJECT_STATUSES = ['in-progress', 'finished', 'archived'] as const;
export type ProjectStatus = (typeof PROJECT_STATUSES)[number];
export type ProjectFilter = ProjectStatus | 'all';
export type CounterKind = 'rows' | 'stitches';

export const COUNTER_ACTIONS = [
  'row-increase',
  'row-decrease',
  'stitch-increase',
  'stitch-decrease',
  'row-reset',
  'stitch-reset',
  'undo',
] as const;

export type CounterAction = (typeof COUNTER_ACTIONS)[number];
export type ReversibleCounterAction = Exclude<CounterAction, 'undo'>;

export type HistoryEntry = {
  id: string;
  action: CounterAction;
  counter: CounterKind;
  previousValue: number;
  newValue: number;
  timestamp: string;
  revertedAction?: ReversibleCounterAction;
};

export type StitchProject = {
  id: string;
  name: string;
  notes: string;
  rowGoal: number | null;
  status: ProjectStatus;
  isFavorite: boolean;
  rowCount: number;
  stitchCount: number;
  rowCounterName: string;
  stitchCounterName: string;
  history: HistoryEntry[];
};

export type UndoAction = {
  id: string;
  projectID: string;
  counter: CounterKind;
  previousValue: number;
  newValue: number;
  originalAction: ReversibleCounterAction;
};

export type CounterOperation = 'increase' | 'decrease' | 'reset';

export type CounterMutation = {
  project: StitchProject;
  undoAction: UndoAction;
};

export type RowProgress = {
  percentage: number;
  fraction: number;
};

export function createProject(): StitchProject {
  return {
    id: createID(),
    name: 'Nuevo proyecto',
    notes: '',
    rowGoal: null,
    status: 'in-progress',
    isFavorite: false,
    rowCount: 0,
    stitchCount: 0,
    rowCounterName: DEFAULT_ROW_COUNTER_NAME,
    stitchCounterName: DEFAULT_STITCH_COUNTER_NAME,
    history: [],
  };
}

export function normalizeProjects(value: unknown): StitchProject[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((project) => normalizeProject(project));
}

export function filterAndSortProjects(
  projects: StitchProject[],
  filter: ProjectFilter,
): StitchProject[] {
  const filteredProjects =
    filter === 'all'
      ? projects
      : projects.filter((project) => project.status === filter);

  return [
    ...filteredProjects.filter((project) => project.isFavorite),
    ...filteredProjects.filter((project) => !project.isFavorite),
  ];
}

export function getRowProgress(
  rowCount: number,
  rowGoal: number | null,
): RowProgress | null {
  if (rowGoal === null || rowGoal <= 0) {
    return null;
  }

  const safeRowCount = normalizeCount(rowCount);
  const fraction = Math.min(1, Math.max(0, safeRowCount / rowGoal));

  return {
    percentage: Math.min(100, Math.max(0, Math.round(fraction * 100))),
    fraction,
  };
}

export function applyCounterOperation(
  project: StitchProject,
  counter: CounterKind,
  operation: CounterOperation,
  timestamp = new Date().toISOString(),
): CounterMutation | null {
  const previousValue = counterValue(project, counter);
  const newValue = nextCounterValue(previousValue, operation);

  if (newValue === previousValue && operation !== 'reset') {
    return null;
  }

  const action = counterAction(counter, operation);
  const historyEntry: HistoryEntry = {
    id: createID(),
    action,
    counter,
    previousValue,
    newValue,
    timestamp,
  };

  return {
    project: withCounterValue(
      {
        ...project,
        history: appendHistory(project.history, historyEntry),
      },
      counter,
      newValue,
    ),
    undoAction: {
      id: createID(),
      projectID: project.id,
      counter,
      previousValue,
      newValue,
      originalAction: action,
    },
  };
}

export function applyUndo(
  project: StitchProject,
  undoAction: UndoAction,
  timestamp = new Date().toISOString(),
): StitchProject | null {
  if (
    project.id !== undoAction.projectID ||
    counterValue(project, undoAction.counter) !== undoAction.newValue
  ) {
    return null;
  }

  const currentValue = counterValue(project, undoAction.counter);
  const restoredValue = normalizeCount(undoAction.previousValue);
  const historyEntry: HistoryEntry = {
    id: createID(),
    action: 'undo',
    counter: undoAction.counter,
    previousValue: currentValue,
    newValue: restoredValue,
    timestamp,
    revertedAction: undoAction.originalAction,
  };

  return withCounterValue(
    {
      ...project,
      history: appendHistory(project.history, historyEntry),
    },
    undoAction.counter,
    restoredValue,
  );
}

export function normalizeCount(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.max(0, Math.trunc(value))
    : 0;
}

export function normalizeRowGoal(value: unknown): number | null {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return null;
  }

  const normalizedGoal = Math.trunc(value);
  return normalizedGoal > 0 ? normalizedGoal : null;
}

function normalizeProject(value: unknown): StitchProject {
  const storedProject = isRecord(value) ? value : {};

  return {
    id:
      typeof storedProject.id === 'string' && storedProject.id.length > 0
        ? storedProject.id
        : createID(),
    name:
      typeof storedProject.name === 'string'
        ? storedProject.name
        : 'Nuevo proyecto',
    notes: typeof storedProject.notes === 'string' ? storedProject.notes : '',
    rowGoal: normalizeRowGoal(storedProject.rowGoal),
    status: isProjectStatus(storedProject.status)
      ? storedProject.status
      : 'in-progress',
    isFavorite:
      typeof storedProject.isFavorite === 'boolean'
        ? storedProject.isFavorite
        : false,
    rowCount: normalizeCount(storedProject.rowCount),
    stitchCount: normalizeCount(storedProject.stitchCount),
    rowCounterName:
      typeof storedProject.rowCounterName === 'string'
        ? storedProject.rowCounterName
        : DEFAULT_ROW_COUNTER_NAME,
    stitchCounterName:
      typeof storedProject.stitchCounterName === 'string'
        ? storedProject.stitchCounterName
        : DEFAULT_STITCH_COUNTER_NAME,
    history: normalizeHistory(storedProject.history),
  };
}

function normalizeHistory(value: unknown): HistoryEntry[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((entry) => normalizeHistoryEntry(entry))
    .filter((entry): entry is HistoryEntry => entry !== null)
    .slice(-MAX_HISTORY_ENTRIES);
}

function normalizeHistoryEntry(value: unknown): HistoryEntry | null {
  if (!isRecord(value)) {
    return null;
  }

  const action = value.action;
  const counter = value.counter;
  const timestamp = value.timestamp;

  if (
    !isCounterAction(action) ||
    !isCounterKind(counter) ||
    typeof timestamp !== 'string' ||
    !Number.isFinite(Date.parse(timestamp))
  ) {
    return null;
  }

  const revertedAction = isReversibleCounterAction(value.revertedAction)
    ? value.revertedAction
    : undefined;

  return {
    id:
      typeof value.id === 'string' && value.id.length > 0
        ? value.id
        : createID(),
    action,
    counter,
    previousValue: normalizeCount(value.previousValue),
    newValue: normalizeCount(value.newValue),
    timestamp,
    ...(action === 'undo' && revertedAction ? { revertedAction } : {}),
  };
}

function appendHistory(
  history: HistoryEntry[],
  entry: HistoryEntry,
): HistoryEntry[] {
  return [...history, entry].slice(-MAX_HISTORY_ENTRIES);
}

function nextCounterValue(
  previousValue: number,
  operation: CounterOperation,
): number {
  switch (operation) {
    case 'increase':
      return previousValue + 1;
    case 'decrease':
      return Math.max(0, previousValue - 1);
    case 'reset':
      return 0;
  }
}

function counterAction(
  counter: CounterKind,
  operation: CounterOperation,
): ReversibleCounterAction {
  if (counter === 'rows') {
    switch (operation) {
      case 'increase':
        return 'row-increase';
      case 'decrease':
        return 'row-decrease';
      case 'reset':
        return 'row-reset';
    }
  }

  switch (operation) {
    case 'increase':
      return 'stitch-increase';
    case 'decrease':
      return 'stitch-decrease';
    case 'reset':
      return 'stitch-reset';
  }
}

function counterValue(project: StitchProject, counter: CounterKind): number {
  return counter === 'rows' ? project.rowCount : project.stitchCount;
}

function withCounterValue(
  project: StitchProject,
  counter: CounterKind,
  value: number,
): StitchProject {
  const normalizedValue = normalizeCount(value);

  return {
    ...project,
    rowCount: counter === 'rows' ? normalizedValue : project.rowCount,
    stitchCount:
      counter === 'stitches' ? normalizedValue : project.stitchCount,
  };
}

function isProjectStatus(value: unknown): value is ProjectStatus {
  return PROJECT_STATUSES.includes(value as ProjectStatus);
}

function isCounterKind(value: unknown): value is CounterKind {
  return value === 'rows' || value === 'stitches';
}

function isCounterAction(value: unknown): value is CounterAction {
  return COUNTER_ACTIONS.includes(value as CounterAction);
}

function isReversibleCounterAction(
  value: unknown,
): value is ReversibleCounterAction {
  return isCounterAction(value) && value !== 'undo';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function createID(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
