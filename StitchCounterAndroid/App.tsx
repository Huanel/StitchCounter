import AsyncStorage from '@react-native-async-storage/async-storage';
import { StatusBar } from 'expo-status-bar';
import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useReducer,
  useState,
} from 'react';
import {
  ActivityIndicator,
  Alert,
  Appearance,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  useColorScheme,
} from 'react-native';

import {
  CounterAction,
  CounterKind,
  DEFAULT_ROW_COUNTER_NAME,
  DEFAULT_STITCH_COUNTER_NAME,
  HistoryEntry,
  ProjectFilter,
  ProjectStatus,
  StitchProject,
  UndoAction,
  applyCounterOperation,
  applyUndo,
  createProject,
  filterAndSortProjects,
  getRowProgress,
  normalizeProjects,
  normalizeRowGoal,
} from './src/projectModel';

const STORAGE_KEY = '@stitchcounter/projects';
const THEME_STORAGE_KEY = '@stitchcounter/theme';
const UNDO_DURATION_MS = 6000;

type ThemePreference = 'system' | 'light' | 'dark';

type EditableProjectFields = Pick<
  StitchProject,
  | 'name'
  | 'notes'
  | 'rowGoal'
  | 'status'
  | 'rowCounterName'
  | 'stitchCounterName'
>;

type ProjectState = {
  projects: StitchProject[];
  undoAction: UndoAction | null;
};

type ProjectAction =
  | { type: 'replace-projects'; projects: StitchProject[] }
  | { type: 'add-project'; project: StitchProject }
  | { type: 'delete-project'; projectID: string }
  | {
      type: 'update-project';
      projectID: string;
      changes: Partial<EditableProjectFields>;
    }
  | { type: 'toggle-favorite'; projectID: string }
  | {
      type: 'change-counter';
      projectID: string;
      counter: CounterKind;
      operation: 'increase' | 'decrease' | 'reset';
    }
  | { type: 'undo-counter'; undoAction: UndoAction }
  | { type: 'clear-undo'; undoID: string };

type Palette = {
  background: string;
  card: string;
  input: string;
  text: string;
  secondaryText: string;
  dustyRose: string;
  lavender: string;
  sage: string;
  terracotta: string;
  softTerracotta: string;
  border: string;
  progressTrack: string;
  favorite: string;
  shadow: string;
  white: string;
};

type AppTheme = {
  colors: Palette;
  styles: ReturnType<typeof createStyles>;
};

const ThemeContext = createContext<AppTheme | null>(null);

const lightColors: Palette = {
  background: '#FAF0DE',
  card: '#FFF9EF',
  input: '#FFFCF6',
  text: '#4A3833',
  secondaryText: '#806A63',
  dustyRose: '#C77380',
  lavender: '#DDD0E8',
  sage: '#789973',
  terracotta: '#B95846',
  softTerracotta: '#EAB9A8',
  border: '#E4D5C2',
  progressTrack: '#E8DCCB',
  favorite: '#9A6413',
  shadow: '#6B4A3D',
  white: '#FFFFFF',
};

const darkColors: Palette = {
  background: '#181513',
  card: '#272220',
  input: '#312A27',
  text: '#F8EFE8',
  secondaryText: '#C8B6AD',
  dustyRose: '#CA7B89',
  lavender: '#594C67',
  sage: '#7FA579',
  terracotta: '#E08370',
  softTerracotta: '#70433A',
  border: '#463B37',
  progressTrack: '#493D38',
  favorite: '#F1C15C',
  shadow: '#000000',
  white: '#FFFFFF',
};

const statusOptions: { value: ProjectStatus; label: string }[] = [
  { value: 'in-progress', label: 'En progreso' },
  { value: 'finished', label: 'Finalizado' },
  { value: 'archived', label: 'Archivado' },
];

const filterOptions: { value: ProjectFilter; label: string }[] = [
  { value: 'all', label: 'Todos' },
  ...statusOptions,
];

const themeOptions: { value: ThemePreference; label: string }[] = [
  { value: 'system', label: 'Sistema' },
  { value: 'light', label: 'Claro' },
  { value: 'dark', label: 'Oscuro' },
];

export default function App() {
  const [{ projects, undoAction }, dispatch] = useReducer(projectReducer, {
    projects: [],
    undoAction: null,
  });
  const [selectedProjectID, setSelectedProjectID] = useState<string | null>(
    null,
  );
  const [isHistoryVisible, setIsHistoryVisible] = useState(false);
  const [isSettingsVisible, setIsSettingsVisible] = useState(false);
  const [projectFilter, setProjectFilter] = useState<ProjectFilter>('all');
  const [themePreference, setThemePreference] =
    useState<ThemePreference>('system');
  const [isLoading, setIsLoading] = useState(true);
  const systemColorScheme = useColorScheme();

  const isDark =
    themePreference === 'dark' ||
    (themePreference === 'system' && systemColorScheme === 'dark');
  const colors = isDark ? darkColors : lightColors;
  const styles = useMemo(() => createStyles(colors), [colors]);
  const theme = useMemo(() => ({ colors, styles }), [colors, styles]);

  useEffect(() => {
    let isMounted = true;

    async function loadLocalData() {
      try {
        const [storedProjects, storedTheme] = await Promise.all([
          AsyncStorage.getItem(STORAGE_KEY),
          AsyncStorage.getItem(THEME_STORAGE_KEY),
        ]);

        if (!isMounted) {
          return;
        }

        if (storedProjects) {
          dispatch({
            type: 'replace-projects',
            projects: normalizeProjects(JSON.parse(storedProjects)),
          });
        }

        if (isThemePreference(storedTheme)) {
          setThemePreference(storedTheme);
        }
      } catch (error) {
        console.warn('No se pudieron cargar los datos locales', error);
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    }

    loadLocalData();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    Appearance.setColorScheme(
      themePreference === 'system' ? null : themePreference,
    );
  }, [themePreference]);

  useEffect(() => {
    if (isLoading) {
      return;
    }

    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(projects)).catch(
      (error) => {
        console.warn('No se pudieron guardar los proyectos', error);
      },
    );
  }, [isLoading, projects]);

  useEffect(() => {
    if (isLoading) {
      return;
    }

    AsyncStorage.setItem(THEME_STORAGE_KEY, themePreference).catch((error) => {
      console.warn('No se pudo guardar la apariencia', error);
    });
  }, [isLoading, themePreference]);

  useEffect(() => {
    if (!undoAction) {
      return;
    }

    const timeout = setTimeout(() => {
      dispatch({ type: 'clear-undo', undoID: undoAction.id });
    }, UNDO_DURATION_MS);

    return () => {
      clearTimeout(timeout);
    };
  }, [undoAction]);

  const selectedProject = useMemo(
    () =>
      projects.find((project) => project.id === selectedProjectID) ?? null,
    [projects, selectedProjectID],
  );

  function addProject() {
    const project = createProject();
    dispatch({ type: 'add-project', project });
    setIsSettingsVisible(false);
    setIsHistoryVisible(false);
    setSelectedProjectID(project.id);
  }

  function openProject(projectID: string) {
    setIsSettingsVisible(false);
    setIsHistoryVisible(false);
    setSelectedProjectID(projectID);
  }

  function closeProject() {
    setIsHistoryVisible(false);
    setSelectedProjectID(null);
  }

  function deleteProject(project: StitchProject) {
    Alert.alert(
      'Borrar proyecto',
      `¿Querés borrar "${displayProjectName(project)}" y sus contadores?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Borrar',
          style: 'destructive',
          onPress: () => {
            dispatch({ type: 'delete-project', projectID: project.id });

            if (selectedProjectID === project.id) {
              closeProject();
            }
          },
        },
      ],
    );
  }

  function updateProject(
    projectID: string,
    changes: Partial<EditableProjectFields>,
  ) {
    dispatch({ type: 'update-project', projectID, changes });
  }

  function confirmReset(project: StitchProject, counter: CounterKind) {
    const counterName =
      counter === 'rows'
        ? displayCounterName(
            project.rowCounterName,
            DEFAULT_ROW_COUNTER_NAME,
          )
        : displayCounterName(
            project.stitchCounterName,
            DEFAULT_STITCH_COUNTER_NAME,
          );

    Alert.alert(
      `Reiniciar ${counterName.toLowerCase()}`,
      `¿Querés volver ${counterName.toLowerCase()} a cero?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Reiniciar',
          style: 'destructive',
          onPress: () => {
            dispatch({
              type: 'change-counter',
              projectID: project.id,
              counter,
              operation: 'reset',
            });
          },
        },
      ],
    );
  }

  function changeTheme(preference: ThemePreference) {
    setThemePreference(preference);
  }

  if (isLoading) {
    return (
      <ThemeContext.Provider value={theme}>
        <SafeAreaView style={styles.screen}>
          <StatusBar style={isDark ? 'light' : 'dark'} />
          <View style={styles.loadingContainer}>
            <ActivityIndicator color={colors.terracotta} />
          </View>
        </SafeAreaView>
      </ThemeContext.Provider>
    );
  }

  return (
    <ThemeContext.Provider value={theme}>
      <SafeAreaView style={styles.screen}>
        <StatusBar style={isDark ? 'light' : 'dark'} />
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : undefined}
          style={styles.keyboardContainer}
        >
          {isSettingsVisible ? (
            <SettingsScreen
              onBack={() => setIsSettingsVisible(false)}
              onChangeTheme={changeTheme}
              themePreference={themePreference}
            />
          ) : selectedProject && isHistoryVisible ? (
            <HistoryScreen
              onBack={() => setIsHistoryVisible(false)}
              project={selectedProject}
            />
          ) : selectedProject ? (
            <ProjectDetail
              onAddCounter={(counter) =>
                dispatch({
                  type: 'change-counter',
                  projectID: selectedProject.id,
                  counter,
                  operation: 'increase',
                })
              }
              onBack={closeProject}
              onChangeCounterName={(counter, name) =>
                updateProject(selectedProject.id, {
                  ...(counter === 'rows'
                    ? { rowCounterName: name }
                    : { stitchCounterName: name }),
                })
              }
              onChangeNotes={(notes) =>
                updateProject(selectedProject.id, { notes })
              }
              onChangeProjectName={(name) =>
                updateProject(selectedProject.id, { name })
              }
              onChangeRowGoal={(rowGoal) =>
                updateProject(selectedProject.id, { rowGoal })
              }
              onChangeStatus={(status) =>
                updateProject(selectedProject.id, { status })
              }
              onOpenHistory={() => setIsHistoryVisible(true)}
              onResetCounter={(counter) =>
                confirmReset(selectedProject, counter)
              }
              onSubtractCounter={(counter) =>
                dispatch({
                  type: 'change-counter',
                  projectID: selectedProject.id,
                  counter,
                  operation: 'decrease',
                })
              }
              onToggleFavorite={() =>
                dispatch({
                  type: 'toggle-favorite',
                  projectID: selectedProject.id,
                })
              }
              project={selectedProject}
            />
          ) : (
            <ProjectList
              filter={projectFilter}
              onAddProject={addProject}
              onChangeFilter={setProjectFilter}
              onDeleteProject={deleteProject}
              onOpenProject={openProject}
              onOpenSettings={() => setIsSettingsVisible(true)}
              onToggleFavorite={(projectID) =>
                dispatch({ type: 'toggle-favorite', projectID })
              }
              projects={projects}
            />
          )}

          {undoAction ? (
            <UndoBar
              onUndo={() =>
                dispatch({ type: 'undo-counter', undoAction })
              }
              undoAction={undoAction}
            />
          ) : null}
        </KeyboardAvoidingView>
      </SafeAreaView>
    </ThemeContext.Provider>
  );
}

type ProjectListProps = {
  projects: StitchProject[];
  filter: ProjectFilter;
  onAddProject: () => void;
  onChangeFilter: (filter: ProjectFilter) => void;
  onOpenProject: (projectID: string) => void;
  onDeleteProject: (project: StitchProject) => void;
  onToggleFavorite: (projectID: string) => void;
  onOpenSettings: () => void;
};

function ProjectList({
  projects,
  filter,
  onAddProject,
  onChangeFilter,
  onOpenProject,
  onDeleteProject,
  onToggleFavorite,
  onOpenSettings,
}: ProjectListProps) {
  const { styles } = useTheme();
  const visibleProjects = useMemo(
    () => filterAndSortProjects(projects, filter),
    [filter, projects],
  );

  return (
    <View style={styles.content}>
      <View style={styles.listHeader}>
        <View style={styles.listHeaderText}>
          <Text style={styles.appTitle}>StitchCounter</Text>
          <Text style={styles.subtitle}>Proyectos</Text>
        </View>
        <IconButton
          accessibilityLabel="Abrir ajustes"
          onPress={onOpenSettings}
          symbol="⚙"
        />
      </View>

      <Pressable
        accessibilityLabel="Agregar proyecto"
        accessibilityRole="button"
        onPress={onAddProject}
        style={({ pressed }) => [
          styles.addButton,
          pressed && styles.pressed,
        ]}
      >
        <Text style={styles.addButtonText}>+ Agregar proyecto</Text>
      </Pressable>

      {projects.length > 0 ? (
        <View style={styles.filterSection}>
          <Text style={styles.sectionLabel}>Filtrar por estado</Text>
          <OptionSelector
            onChange={onChangeFilter}
            options={filterOptions}
            selectedValue={filter}
          />
        </View>
      ) : null}

      {projects.length === 0 ? (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyTitle}>Todavía no hay proyectos</Text>
          <Text style={styles.emptyText}>
            Agregá uno para empezar a contar puntos y vueltas.
          </Text>
        </View>
      ) : visibleProjects.length === 0 ? (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyTitle}>No hay proyectos en este estado</Text>
          <Text style={styles.emptyText}>
            Elegí otro filtro para ver tus proyectos.
          </Text>
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.projectList}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {visibleProjects.map((project) => (
            <ProjectRow
              key={project.id}
              onDelete={() => onDeleteProject(project)}
              onOpen={() => onOpenProject(project.id)}
              onToggleFavorite={() => onToggleFavorite(project.id)}
              project={project}
            />
          ))}
        </ScrollView>
      )}
    </View>
  );
}

type ProjectRowProps = {
  project: StitchProject;
  onOpen: () => void;
  onDelete: () => void;
  onToggleFavorite: () => void;
};

function ProjectRow({
  project,
  onOpen,
  onDelete,
  onToggleFavorite,
}: ProjectRowProps) {
  const { colors, styles } = useTheme();
  const progress = getRowProgress(project.rowCount, project.rowGoal);

  return (
    <View style={styles.projectRow}>
      <Pressable
        accessibilityLabel={
          project.isFavorite
            ? `Quitar ${displayProjectName(project)} de favoritos`
            : `Marcar ${displayProjectName(project)} como favorito`
        }
        accessibilityRole="button"
        accessibilityState={{ checked: project.isFavorite }}
        onPress={onToggleFavorite}
        style={({ pressed }) => [
          styles.favoriteButton,
          pressed && styles.pressed,
        ]}
      >
        <Text
          style={[
            styles.favoriteIcon,
            { color: project.isFavorite ? colors.favorite : colors.secondaryText },
          ]}
        >
          {project.isFavorite ? '★' : '☆'}
        </Text>
      </Pressable>

      <Pressable
        accessibilityLabel={`Abrir ${displayProjectName(project)}`}
        accessibilityRole="button"
        onPress={onOpen}
        style={({ pressed }) => [
          styles.projectRowContent,
          pressed && styles.pressed,
        ]}
      >
        <View style={styles.projectTextGroup}>
          <Text style={styles.projectName} numberOfLines={2}>
            {displayProjectName(project)}
          </Text>
          <View style={styles.projectMetaLine}>
            <Text style={styles.statusText}>{statusLabel(project.status)}</Text>
            {progress && project.rowGoal ? (
              <Text style={styles.projectProgressText}>
                {project.rowCount}/{project.rowGoal} vueltas ·{' '}
                {progress.percentage} %
              </Text>
            ) : null}
          </View>
          <View style={styles.projectSummary}>
            <Text style={styles.projectSummaryText} numberOfLines={1}>
              {displayCounterName(
                project.rowCounterName,
                DEFAULT_ROW_COUNTER_NAME,
              )}
              : {project.rowCount}
            </Text>
            <Text style={styles.projectSummaryText} numberOfLines={1}>
              {displayCounterName(
                project.stitchCounterName,
                DEFAULT_STITCH_COUNTER_NAME,
              )}
              : {project.stitchCount}
            </Text>
          </View>
        </View>
        <Text style={styles.chevron}>›</Text>
      </Pressable>

      <Pressable
        accessibilityLabel={`Borrar ${displayProjectName(project)}`}
        accessibilityRole="button"
        onPress={onDelete}
        style={({ pressed }) => [
          styles.deleteButton,
          pressed && styles.pressed,
        ]}
      >
        <Text style={styles.deleteButtonText}>×</Text>
      </Pressable>
    </View>
  );
}

type ProjectDetailProps = {
  project: StitchProject;
  onBack: () => void;
  onOpenHistory: () => void;
  onToggleFavorite: () => void;
  onChangeProjectName: (name: string) => void;
  onChangeCounterName: (counter: CounterKind, name: string) => void;
  onChangeNotes: (notes: string) => void;
  onChangeRowGoal: (rowGoal: number | null) => void;
  onChangeStatus: (status: ProjectStatus) => void;
  onAddCounter: (counter: CounterKind) => void;
  onSubtractCounter: (counter: CounterKind) => void;
  onResetCounter: (counter: CounterKind) => void;
};

function ProjectDetail({
  project,
  onBack,
  onOpenHistory,
  onToggleFavorite,
  onChangeProjectName,
  onChangeCounterName,
  onChangeNotes,
  onChangeRowGoal,
  onChangeStatus,
  onAddCounter,
  onSubtractCounter,
  onResetCounter,
}: ProjectDetailProps) {
  const { colors, styles } = useTheme();
  const progress = getRowProgress(project.rowCount, project.rowGoal);

  function changeGoal(text: string) {
    const numericText = text.replace(/\D/g, '');
    onChangeRowGoal(
      numericText.length === 0 ? null : normalizeRowGoal(Number(numericText)),
    );
  }

  return (
    <ScrollView
      contentContainerStyle={styles.detailContent}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      <View style={styles.detailToolbar}>
        <Pressable
          accessibilityLabel="Volver a proyectos"
          accessibilityRole="button"
          onPress={onBack}
          style={({ pressed }) => [
            styles.backButton,
            pressed && styles.pressed,
          ]}
        >
          <Text style={styles.backButtonText}>‹ Proyectos</Text>
        </Pressable>

        <Pressable
          accessibilityLabel="Ver historial del proyecto"
          accessibilityRole="button"
          onPress={onOpenHistory}
          style={({ pressed }) => [
            styles.historyButton,
            pressed && styles.pressed,
          ]}
        >
          <Text style={styles.historyButtonText}>Historial</Text>
        </Pressable>
      </View>

      <View style={styles.detailHeader}>
        <TextInput
          accessibilityLabel="Nombre del proyecto"
          onChangeText={onChangeProjectName}
          placeholder="Nombre del proyecto"
          placeholderTextColor={colors.secondaryText}
          returnKeyType="done"
          style={styles.projectTitleInput}
          value={project.name}
        />
        <Pressable
          accessibilityLabel={
            project.isFavorite
              ? 'Quitar proyecto de favoritos'
              : 'Marcar proyecto como favorito'
          }
          accessibilityRole="button"
          accessibilityState={{ checked: project.isFavorite }}
          onPress={onToggleFavorite}
          style={({ pressed }) => [
            styles.detailFavoriteButton,
            pressed && styles.pressed,
          ]}
        >
          <Text
            style={[
              styles.detailFavoriteIcon,
              {
                color: project.isFavorite
                  ? colors.favorite
                  : colors.secondaryText,
              },
            ]}
          >
            {project.isFavorite ? '★' : '☆'}
          </Text>
        </Pressable>
        <Text style={styles.subtitle}>Contador de puntos y vueltas</Text>
      </View>

      <View style={styles.infoSection}>
        <Text style={styles.sectionTitle}>Estado del proyecto</Text>
        <OptionSelector
          onChange={onChangeStatus}
          options={statusOptions}
          selectedValue={project.status}
        />
      </View>

      <View style={styles.infoSection}>
        <View style={styles.goalHeader}>
          <View style={styles.goalHeaderText}>
            <Text style={styles.sectionTitle}>Objetivo de vueltas</Text>
            <Text style={styles.sectionHint}>Opcional</Text>
          </View>
          {project.rowGoal !== null ? (
            <Pressable
              accessibilityLabel="Quitar objetivo de vueltas"
              accessibilityRole="button"
              onPress={() => onChangeRowGoal(null)}
              style={({ pressed }) => [
                styles.clearGoalButton,
                pressed && styles.pressed,
              ]}
            >
              <Text style={styles.clearGoalButtonText}>Sin objetivo</Text>
            </Pressable>
          ) : null}
        </View>

        <TextInput
          accessibilityLabel="Objetivo de vueltas"
          keyboardType="number-pad"
          onChangeText={changeGoal}
          placeholder="Ej. 40"
          placeholderTextColor={colors.secondaryText}
          style={styles.goalInput}
          value={project.rowGoal?.toString() ?? ''}
        />

        {progress && project.rowGoal ? (
          <View style={styles.progressSection}>
            <View style={styles.progressLabels}>
              <Text style={styles.progressCount}>
                {project.rowCount} / {project.rowGoal} vueltas
              </Text>
              <Text style={styles.progressPercentage}>
                {progress.percentage} %
              </Text>
            </View>
            <View
              accessibilityLabel={`Progreso de vueltas: ${progress.percentage} por ciento`}
              accessibilityRole="progressbar"
              accessibilityValue={{
                min: 0,
                max: 100,
                now: progress.percentage,
              }}
              style={styles.progressTrack}
            >
              <View
                style={[
                  styles.progressFill,
                  {
                    width: `${progress.fraction * 100}%`,
                  },
                ]}
              />
            </View>
          </View>
        ) : (
          <Text style={styles.noGoalText}>Este proyecto no tiene objetivo.</Text>
        )}
      </View>

      <View style={styles.counterStack}>
        <CounterCard
          accentColor={colors.dustyRose}
          defaultTitle={DEFAULT_ROW_COUNTER_NAME}
          onChangeTitle={(name) => onChangeCounterName('rows', name)}
          onMinus={() => onSubtractCounter('rows')}
          onPlus={() => onAddCounter('rows')}
          onReset={() => onResetCounter('rows')}
          title={project.rowCounterName}
          value={project.rowCount}
        />

        <CounterCard
          accentColor={colors.sage}
          defaultTitle={DEFAULT_STITCH_COUNTER_NAME}
          onChangeTitle={(name) => onChangeCounterName('stitches', name)}
          onMinus={() => onSubtractCounter('stitches')}
          onPlus={() => onAddCounter('stitches')}
          onReset={() => onResetCounter('stitches')}
          title={project.stitchCounterName}
          value={project.stitchCount}
        />
      </View>

      <View style={styles.notesSection}>
        <Text style={styles.sectionTitle}>Notas</Text>
        <TextInput
          accessibilityLabel="Notas del proyecto"
          multiline
          onChangeText={onChangeNotes}
          placeholder="Escribe recordatorios, cambios de color o instrucciones del patrón…"
          placeholderTextColor={colors.secondaryText}
          style={styles.notesInput}
          textAlignVertical="top"
          value={project.notes}
        />
      </View>
    </ScrollView>
  );
}

type CounterCardProps = {
  title: string;
  defaultTitle: string;
  value: number;
  accentColor: string;
  onChangeTitle: (title: string) => void;
  onMinus: () => void;
  onPlus: () => void;
  onReset: () => void;
};

function CounterCard({
  title,
  defaultTitle,
  value,
  accentColor,
  onChangeTitle,
  onMinus,
  onPlus,
  onReset,
}: CounterCardProps) {
  const { colors, styles } = useTheme();
  const displayTitle = displayCounterName(title, defaultTitle);

  return (
    <View style={styles.counterCard}>
      <TextInput
        accessibilityLabel={`Nombre de ${defaultTitle.toLowerCase()}`}
        onChangeText={onChangeTitle}
        placeholder={defaultTitle}
        placeholderTextColor={colors.secondaryText}
        returnKeyType="done"
        style={styles.counterTitleInput}
        value={title}
      />

      <Text
        accessibilityLabel={`${displayTitle}: ${value}`}
        style={styles.counterValue}
      >
        {value}
      </Text>

      <View style={styles.counterButtons}>
        <RoundCounterButton
          accessibilityLabel={`Restar ${displayTitle.toLowerCase()}`}
          backgroundColor={colors.lavender}
          disabled={value <= 0}
          foregroundColor={colors.text}
          onPress={onMinus}
          symbol="−"
        />

        <RoundCounterButton
          accessibilityLabel={`Sumar ${displayTitle.toLowerCase()}`}
          backgroundColor={accentColor}
          foregroundColor={colors.white}
          onPress={onPlus}
          symbol="+"
        />
      </View>

      <Pressable
        accessibilityLabel={`Reiniciar ${displayTitle.toLowerCase()}`}
        accessibilityRole="button"
        onPress={onReset}
        style={({ pressed }) => [
          styles.resetButton,
          pressed && styles.pressed,
        ]}
      >
        <Text style={styles.resetButtonText}>
          Reiniciar {displayTitle.toLowerCase()}
        </Text>
      </Pressable>
    </View>
  );
}

type RoundCounterButtonProps = {
  symbol: string;
  backgroundColor: string;
  foregroundColor: string;
  accessibilityLabel: string;
  onPress: () => void;
  disabled?: boolean;
};

function RoundCounterButton({
  symbol,
  backgroundColor,
  foregroundColor,
  accessibilityLabel,
  onPress,
  disabled = false,
}: RoundCounterButtonProps) {
  const { styles } = useTheme();

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={{ disabled }}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => [
        styles.roundButton,
        { backgroundColor },
        disabled && styles.disabledButton,
        pressed && styles.roundButtonPressed,
      ]}
    >
      <Text style={[styles.roundButtonText, { color: foregroundColor }]}>
        {symbol}
      </Text>
    </Pressable>
  );
}

type SettingsScreenProps = {
  themePreference: ThemePreference;
  onChangeTheme: (preference: ThemePreference) => void;
  onBack: () => void;
};

function SettingsScreen({
  themePreference,
  onChangeTheme,
  onBack,
}: SettingsScreenProps) {
  const { styles } = useTheme();

  return (
    <ScrollView
      contentContainerStyle={styles.simpleScreenContent}
      showsVerticalScrollIndicator={false}
    >
      <Pressable
        accessibilityLabel="Volver a proyectos"
        accessibilityRole="button"
        onPress={onBack}
        style={({ pressed }) => [
          styles.backButton,
          pressed && styles.pressed,
        ]}
      >
        <Text style={styles.backButtonText}>‹ Proyectos</Text>
      </Pressable>

      <View style={styles.simpleHeader}>
        <Text style={styles.screenTitle}>Ajustes</Text>
      </View>

      <View style={styles.infoSection}>
        <Text style={styles.sectionTitle}>Apariencia</Text>
        <OptionSelector
          onChange={onChangeTheme}
          options={themeOptions}
          selectedValue={themePreference}
        />
      </View>
    </ScrollView>
  );
}

type HistoryScreenProps = {
  project: StitchProject;
  onBack: () => void;
};

function HistoryScreen({ project, onBack }: HistoryScreenProps) {
  const { styles } = useTheme();
  const entries = useMemo(() => [...project.history].reverse(), [project.history]);

  return (
    <View style={styles.historyScreen}>
      <View style={styles.historyTop}>
        <Pressable
          accessibilityLabel="Volver al proyecto"
          accessibilityRole="button"
          onPress={onBack}
          style={({ pressed }) => [
            styles.backButton,
            pressed && styles.pressed,
          ]}
        >
          <Text style={styles.backButtonText}>‹ Proyecto</Text>
        </Pressable>

        <View style={styles.simpleHeader}>
          <Text style={styles.screenTitle}>Historial</Text>
          <Text style={styles.subtitle} numberOfLines={2}>
            {displayProjectName(project)}
          </Text>
        </View>
      </View>

      {entries.length === 0 ? (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyTitle}>Todavía no hay movimientos</Text>
          <Text style={styles.emptyText}>
            Los cambios de puntos y vueltas aparecerán acá.
          </Text>
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.historyList}
          showsVerticalScrollIndicator={false}
        >
          {entries.map((entry) => (
            <HistoryRow entry={entry} key={entry.id} />
          ))}
        </ScrollView>
      )}
    </View>
  );
}

function HistoryRow({ entry }: { entry: HistoryEntry }) {
  const { styles } = useTheme();

  return (
    <View style={styles.historyRow}>
      <View style={styles.historyRowText}>
        <Text style={styles.historyAction}>{historyActionLabel(entry)}</Text>
        <Text style={styles.historyDate}>{formatHistoryDate(entry.timestamp)}</Text>
      </View>
      <Text
        accessibilityLabel={`Valor anterior ${entry.previousValue}, valor nuevo ${entry.newValue}`}
        style={styles.historyValues}
      >
        {entry.previousValue} → {entry.newValue}
      </Text>
    </View>
  );
}

type OptionSelectorProps<T extends string> = {
  options: { value: T; label: string }[];
  selectedValue: T;
  onChange: (value: T) => void;
};

function OptionSelector<T extends string>({
  options,
  selectedValue,
  onChange,
}: OptionSelectorProps<T>) {
  const { styles } = useTheme();

  return (
    <View style={styles.optionGroup}>
      {options.map((option) => {
        const isSelected = option.value === selectedValue;

        return (
          <Pressable
            accessibilityLabel={option.label}
            accessibilityRole="button"
            accessibilityState={{ selected: isSelected }}
            key={option.value}
            onPress={() => onChange(option.value)}
            style={({ pressed }) => [
              styles.optionButton,
              isSelected && styles.optionButtonSelected,
              pressed && styles.pressed,
            ]}
          >
            <Text
              style={[
                styles.optionButtonText,
                isSelected && styles.optionButtonTextSelected,
              ]}
            >
              {option.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

type IconButtonProps = {
  symbol: string;
  accessibilityLabel: string;
  onPress: () => void;
};

function IconButton({
  symbol,
  accessibilityLabel,
  onPress,
}: IconButtonProps) {
  const { styles } = useTheme();

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [
        styles.iconButton,
        pressed && styles.pressed,
      ]}
    >
      <Text style={styles.iconButtonText}>{symbol}</Text>
    </Pressable>
  );
}

type UndoBarProps = {
  undoAction: UndoAction;
  onUndo: () => void;
};

function UndoBar({ undoAction, onUndo }: UndoBarProps) {
  const { styles } = useTheme();
  const counterName = undoAction.counter === 'rows' ? 'vueltas' : 'puntos';

  return (
    <View
      accessibilityLiveRegion="polite"
      accessibilityRole="alert"
      style={styles.undoBar}
    >
      <Text style={styles.undoText} numberOfLines={2}>
        {counterName}: {undoAction.previousValue} → {undoAction.newValue}
      </Text>
      <Pressable
        accessibilityLabel={`Deshacer cambio de ${counterName}`}
        accessibilityRole="button"
        onPress={onUndo}
        style={({ pressed }) => [
          styles.undoButton,
          pressed && styles.pressed,
        ]}
      >
        <Text style={styles.undoButtonText}>Deshacer</Text>
      </Pressable>
    </View>
  );
}

function projectReducer(
  state: ProjectState,
  action: ProjectAction,
): ProjectState {
  switch (action.type) {
    case 'replace-projects':
      return {
        projects: action.projects,
        undoAction: null,
      };
    case 'add-project':
      return {
        projects: [action.project, ...state.projects],
        undoAction: state.undoAction,
      };
    case 'delete-project':
      return {
        projects: state.projects.filter(
          (project) => project.id !== action.projectID,
        ),
        undoAction:
          state.undoAction?.projectID === action.projectID
            ? null
            : state.undoAction,
      };
    case 'update-project':
      return {
        ...state,
        projects: state.projects.map((project) =>
          project.id === action.projectID
            ? { ...project, ...action.changes }
            : project,
        ),
      };
    case 'toggle-favorite':
      return {
        ...state,
        projects: state.projects.map((project) =>
          project.id === action.projectID
            ? { ...project, isFavorite: !project.isFavorite }
            : project,
        ),
      };
    case 'change-counter': {
      let nextUndoAction = state.undoAction;

      const updatedProjects = state.projects.map((project) => {
        if (project.id !== action.projectID) {
          return project;
        }

        const mutation = applyCounterOperation(
          project,
          action.counter,
          action.operation,
        );

        if (!mutation) {
          return project;
        }

        nextUndoAction = mutation.undoAction;
        return mutation.project;
      });

      return {
        projects: updatedProjects,
        undoAction: nextUndoAction,
      };
    }
    case 'undo-counter':
      return {
        projects: state.projects.map((project) => {
          if (project.id !== action.undoAction.projectID) {
            return project;
          }

          return applyUndo(project, action.undoAction) ?? project;
        }),
        undoAction: null,
      };
    case 'clear-undo':
      return {
        ...state,
        undoAction:
          state.undoAction?.id === action.undoID ? null : state.undoAction,
      };
  }
}

function useTheme(): AppTheme {
  const theme = useContext(ThemeContext);

  if (!theme) {
    throw new Error('ThemeContext no está disponible');
  }

  return theme;
}

function displayProjectName(project: StitchProject): string {
  const trimmedName = project.name.trim();
  return trimmedName.length > 0 ? trimmedName : 'Proyecto sin nombre';
}

function displayCounterName(name: string, defaultName: string): string {
  const trimmedName = name.trim();
  return trimmedName.length > 0 ? trimmedName : defaultName;
}

function statusLabel(status: ProjectStatus): string {
  return (
    statusOptions.find((option) => option.value === status)?.label ??
    'En progreso'
  );
}

function historyActionLabel(entry: HistoryEntry): string {
  if (entry.action === 'undo') {
    return entry.revertedAction
      ? `Deshacer: ${counterActionLabel(entry.revertedAction).toLowerCase()}`
      : 'Deshacer cambio';
  }

  return counterActionLabel(entry.action);
}

function counterActionLabel(action: Exclude<CounterAction, 'undo'>): string {
  switch (action) {
    case 'row-increase':
      return 'Aumento de vueltas';
    case 'row-decrease':
      return 'Reducción de vueltas';
    case 'stitch-increase':
      return 'Aumento de puntos';
    case 'stitch-decrease':
      return 'Reducción de puntos';
    case 'row-reset':
      return 'Reinicio de vueltas';
    case 'stitch-reset':
      return 'Reinicio de puntos';
  }
}

function formatHistoryDate(timestamp: string): string {
  const date = new Date(timestamp);

  if (!Number.isFinite(date.getTime())) {
    return '';
  }

  return date.toLocaleString('es-AR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function isThemePreference(value: unknown): value is ThemePreference {
  return value === 'system' || value === 'light' || value === 'dark';
}

function createStyles(colors: Palette) {
  return StyleSheet.create({
    screen: {
      flex: 1,
      backgroundColor: colors.background,
    },
    keyboardContainer: {
      flex: 1,
    },
    loadingContainer: {
      flex: 1,
      alignItems: 'center',
      justifyContent: 'center',
    },
    content: {
      flex: 1,
      paddingHorizontal: 18,
      paddingTop: 18,
    },
    detailContent: {
      flexGrow: 1,
      gap: 18,
      paddingBottom: 112,
      paddingHorizontal: 18,
      paddingTop: 12,
    },
    simpleScreenContent: {
      flexGrow: 1,
      gap: 18,
      paddingBottom: 40,
      paddingHorizontal: 18,
      paddingTop: 30,
    },
    listHeader: {
      alignItems: 'center',
      flexDirection: 'row',
      gap: 12,
      justifyContent: 'space-between',
      marginBottom: 18,
    },
    listHeaderText: {
      alignItems: 'flex-start',
      flex: 1,
    },
    appTitle: {
      color: colors.text,
      fontSize: 34,
      fontWeight: '800',
      letterSpacing: 0,
      marginBottom: 2,
    },
    screenTitle: {
      color: colors.text,
      fontSize: 32,
      fontWeight: '800',
      letterSpacing: 0,
      textAlign: 'center',
    },
    subtitle: {
      color: colors.secondaryText,
      fontSize: 16,
      fontWeight: '600',
      letterSpacing: 0,
      textAlign: 'center',
    },
    iconButton: {
      alignItems: 'center',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 22,
      borderWidth: 1,
      height: 44,
      justifyContent: 'center',
      width: 44,
    },
    iconButtonText: {
      color: colors.text,
      fontSize: 22,
      fontWeight: '700',
      lineHeight: 26,
    },
    addButton: {
      alignItems: 'center',
      backgroundColor: colors.dustyRose,
      borderRadius: 18,
      marginBottom: 16,
      paddingVertical: 14,
    },
    addButtonText: {
      color: colors.white,
      fontSize: 17,
      fontWeight: '700',
      letterSpacing: 0,
    },
    filterSection: {
      gap: 8,
      marginBottom: 14,
    },
    sectionLabel: {
      color: colors.secondaryText,
      fontSize: 13,
      fontWeight: '700',
      letterSpacing: 0,
    },
    optionGroup: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      gap: 8,
    },
    optionButton: {
      alignItems: 'center',
      backgroundColor: colors.input,
      borderColor: colors.border,
      borderRadius: 8,
      borderWidth: 1,
      flexGrow: 1,
      minHeight: 42,
      minWidth: 92,
      justifyContent: 'center',
      paddingHorizontal: 12,
      paddingVertical: 9,
    },
    optionButtonSelected: {
      backgroundColor: colors.terracotta,
      borderColor: colors.terracotta,
    },
    optionButtonText: {
      color: colors.text,
      fontSize: 14,
      fontWeight: '700',
      letterSpacing: 0,
      textAlign: 'center',
    },
    optionButtonTextSelected: {
      color: colors.white,
    },
    projectList: {
      paddingBottom: 104,
      rowGap: 12,
    },
    emptyCard: {
      alignItems: 'center',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 24,
      borderWidth: 1,
      paddingHorizontal: 18,
      paddingVertical: 28,
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 6 },
      shadowOpacity: 0.12,
      shadowRadius: 12,
      elevation: 3,
    },
    emptyTitle: {
      color: colors.text,
      fontSize: 21,
      fontWeight: '700',
      letterSpacing: 0,
      marginBottom: 8,
      textAlign: 'center',
    },
    emptyText: {
      color: colors.secondaryText,
      fontSize: 15,
      fontWeight: '600',
      letterSpacing: 0,
      textAlign: 'center',
    },
    projectRow: {
      alignItems: 'center',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 24,
      borderWidth: 1,
      flexDirection: 'row',
      gap: 7,
      paddingHorizontal: 10,
      paddingVertical: 16,
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 5 },
      shadowOpacity: 0.1,
      shadowRadius: 10,
      elevation: 3,
    },
    favoriteButton: {
      alignItems: 'center',
      height: 42,
      justifyContent: 'center',
      width: 38,
    },
    favoriteIcon: {
      fontSize: 28,
      lineHeight: 32,
    },
    projectRowContent: {
      alignItems: 'center',
      flex: 1,
      flexDirection: 'row',
      gap: 8,
      minHeight: 60,
    },
    projectTextGroup: {
      flex: 1,
      minWidth: 0,
    },
    projectName: {
      color: colors.text,
      fontSize: 19,
      fontWeight: '700',
      letterSpacing: 0,
      marginBottom: 6,
    },
    projectMetaLine: {
      alignItems: 'center',
      flexDirection: 'row',
      flexWrap: 'wrap',
      gap: 8,
      marginBottom: 7,
    },
    statusText: {
      color: colors.terracotta,
      fontSize: 12,
      fontWeight: '800',
      letterSpacing: 0,
    },
    projectProgressText: {
      color: colors.secondaryText,
      fontSize: 12,
      fontWeight: '600',
      letterSpacing: 0,
    },
    projectSummary: {
      flexDirection: 'row',
      flexWrap: 'wrap',
      gap: 12,
    },
    projectSummaryText: {
      color: colors.secondaryText,
      fontSize: 13,
      fontWeight: '600',
      letterSpacing: 0,
    },
    chevron: {
      color: colors.secondaryText,
      fontSize: 26,
      fontWeight: '700',
      letterSpacing: 0,
    },
    deleteButton: {
      alignItems: 'center',
      backgroundColor: colors.softTerracotta,
      borderRadius: 19,
      height: 38,
      justifyContent: 'center',
      width: 38,
    },
    deleteButtonText: {
      color: colors.text,
      fontSize: 24,
      fontWeight: '700',
      lineHeight: 26,
    },
    detailToolbar: {
      alignItems: 'center',
      flexDirection: 'row',
      justifyContent: 'space-between',
    },
    backButton: {
      alignSelf: 'flex-start',
      minHeight: 42,
      justifyContent: 'center',
      paddingHorizontal: 2,
      paddingVertical: 8,
    },
    backButtonText: {
      color: colors.terracotta,
      fontSize: 17,
      fontWeight: '700',
      letterSpacing: 0,
    },
    historyButton: {
      backgroundColor: colors.input,
      borderColor: colors.border,
      borderRadius: 8,
      borderWidth: 1,
      minHeight: 40,
      justifyContent: 'center',
      paddingHorizontal: 13,
    },
    historyButtonText: {
      color: colors.terracotta,
      fontSize: 14,
      fontWeight: '800',
      letterSpacing: 0,
    },
    detailHeader: {
      alignItems: 'center',
      marginBottom: 2,
      position: 'relative',
    },
    projectTitleInput: {
      color: colors.text,
      fontSize: 32,
      fontWeight: '800',
      letterSpacing: 0,
      marginBottom: 6,
      minHeight: 48,
      paddingHorizontal: 48,
      textAlign: 'center',
      width: '100%',
    },
    detailFavoriteButton: {
      alignItems: 'center',
      height: 44,
      justifyContent: 'center',
      position: 'absolute',
      right: 0,
      top: 0,
      width: 44,
    },
    detailFavoriteIcon: {
      fontSize: 30,
      lineHeight: 34,
    },
    infoSection: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 20,
      borderWidth: 1,
      gap: 12,
      paddingHorizontal: 16,
      paddingVertical: 18,
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.08,
      shadowRadius: 8,
      elevation: 2,
    },
    sectionTitle: {
      color: colors.text,
      fontSize: 18,
      fontWeight: '800',
      letterSpacing: 0,
    },
    sectionHint: {
      color: colors.secondaryText,
      fontSize: 13,
      fontWeight: '600',
      letterSpacing: 0,
    },
    goalHeader: {
      alignItems: 'center',
      flexDirection: 'row',
      gap: 12,
      justifyContent: 'space-between',
    },
    goalHeaderText: {
      flex: 1,
      gap: 2,
    },
    clearGoalButton: {
      minHeight: 38,
      justifyContent: 'center',
      paddingHorizontal: 8,
    },
    clearGoalButtonText: {
      color: colors.terracotta,
      fontSize: 13,
      fontWeight: '800',
      letterSpacing: 0,
    },
    goalInput: {
      backgroundColor: colors.input,
      borderColor: colors.border,
      borderRadius: 8,
      borderWidth: 1,
      color: colors.text,
      fontSize: 20,
      fontWeight: '700',
      minHeight: 48,
      paddingHorizontal: 14,
      paddingVertical: 8,
    },
    progressSection: {
      gap: 9,
    },
    progressLabels: {
      alignItems: 'center',
      flexDirection: 'row',
      gap: 12,
      justifyContent: 'space-between',
    },
    progressCount: {
      color: colors.text,
      flex: 1,
      fontSize: 15,
      fontWeight: '700',
      letterSpacing: 0,
    },
    progressPercentage: {
      color: colors.terracotta,
      fontSize: 16,
      fontWeight: '800',
      letterSpacing: 0,
    },
    progressTrack: {
      backgroundColor: colors.progressTrack,
      borderRadius: 6,
      height: 12,
      overflow: 'hidden',
      width: '100%',
    },
    progressFill: {
      backgroundColor: colors.sage,
      borderRadius: 6,
      height: '100%',
    },
    noGoalText: {
      color: colors.secondaryText,
      fontSize: 14,
      fontWeight: '600',
      letterSpacing: 0,
    },
    counterStack: {
      gap: 18,
    },
    counterCard: {
      alignItems: 'center',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 28,
      borderWidth: 1,
      paddingHorizontal: 18,
      paddingVertical: 24,
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 6 },
      shadowOpacity: 0.12,
      shadowRadius: 12,
      elevation: 3,
    },
    counterTitleInput: {
      color: colors.text,
      fontSize: 24,
      fontWeight: '700',
      letterSpacing: 0,
      minHeight: 36,
      paddingHorizontal: 4,
      paddingVertical: 0,
      textAlign: 'center',
      width: '100%',
    },
    counterValue: {
      color: colors.text,
      fontSize: 76,
      fontWeight: '800',
      letterSpacing: 0,
      marginVertical: 12,
      textAlign: 'center',
    },
    counterButtons: {
      flexDirection: 'row',
      gap: 22,
      marginBottom: 18,
    },
    roundButton: {
      alignItems: 'center',
      borderRadius: 38,
      height: 76,
      justifyContent: 'center',
      width: 76,
    },
    roundButtonPressed: {
      transform: [{ scale: 0.97 }],
    },
    disabledButton: {
      opacity: 0.42,
    },
    roundButtonText: {
      fontSize: 38,
      fontWeight: '800',
      lineHeight: 44,
    },
    resetButton: {
      backgroundColor: colors.softTerracotta,
      borderRadius: 18,
      paddingHorizontal: 18,
      paddingVertical: 10,
    },
    resetButtonText: {
      color: colors.text,
      fontSize: 15,
      fontWeight: '700',
      letterSpacing: 0,
    },
    notesSection: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 20,
      borderWidth: 1,
      gap: 12,
      paddingHorizontal: 16,
      paddingVertical: 18,
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 4 },
      shadowOpacity: 0.08,
      shadowRadius: 8,
      elevation: 2,
    },
    notesInput: {
      backgroundColor: colors.input,
      borderColor: colors.border,
      borderRadius: 8,
      borderWidth: 1,
      color: colors.text,
      fontSize: 16,
      lineHeight: 23,
      minHeight: 132,
      paddingHorizontal: 13,
      paddingVertical: 12,
    },
    simpleHeader: {
      alignItems: 'center',
      gap: 5,
      marginBottom: 4,
    },
    historyScreen: {
      flex: 1,
      paddingHorizontal: 18,
      paddingTop: 30,
    },
    historyTop: {
      marginBottom: 18,
    },
    historyList: {
      paddingBottom: 104,
      rowGap: 10,
    },
    historyRow: {
      alignItems: 'center',
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderRadius: 8,
      borderWidth: 1,
      flexDirection: 'row',
      gap: 12,
      minHeight: 72,
      paddingHorizontal: 14,
      paddingVertical: 13,
    },
    historyRowText: {
      flex: 1,
      gap: 4,
      minWidth: 0,
    },
    historyAction: {
      color: colors.text,
      fontSize: 15,
      fontWeight: '700',
      letterSpacing: 0,
    },
    historyDate: {
      color: colors.secondaryText,
      fontSize: 12,
      fontWeight: '600',
      letterSpacing: 0,
    },
    historyValues: {
      color: colors.terracotta,
      fontSize: 16,
      fontWeight: '800',
      letterSpacing: 0,
    },
    undoBar: {
      alignItems: 'center',
      backgroundColor: colors.text,
      borderColor: colors.border,
      borderRadius: 8,
      borderWidth: 1,
      bottom: 14,
      flexDirection: 'row',
      gap: 12,
      left: 16,
      minHeight: 58,
      paddingHorizontal: 16,
      paddingVertical: 10,
      position: 'absolute',
      right: 16,
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 5 },
      shadowOpacity: 0.25,
      shadowRadius: 10,
      elevation: 8,
    },
    undoText: {
      color: colors.background,
      flex: 1,
      fontSize: 14,
      fontWeight: '700',
      letterSpacing: 0,
    },
    undoButton: {
      minHeight: 40,
      justifyContent: 'center',
      paddingHorizontal: 6,
    },
    undoButtonText: {
      color: colors.dustyRose,
      fontSize: 15,
      fontWeight: '900',
      letterSpacing: 0,
    },
    pressed: {
      opacity: 0.7,
    },
  });
}
