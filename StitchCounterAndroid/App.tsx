import AsyncStorage from '@react-native-async-storage/async-storage';
import { StatusBar } from 'expo-status-bar';
import { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

const STORAGE_KEY = '@stitchcounter/projects';
const DEFAULT_ROW_COUNTER_NAME = 'Vueltas';
const DEFAULT_STITCH_COUNTER_NAME = 'Puntos';

type StitchProject = {
  id: string;
  name: string;
  rowCount: number;
  stitchCount: number;
  rowCounterName: string;
  stitchCounterName: string;
};

type CounterKind = 'rows' | 'stitches';

const colors = {
  background: '#FAF0DE',
  card: '#FFF9EF',
  text: '#4A3833',
  secondaryText: '#8C736B',
  dustyRose: '#C77380',
  lavender: '#DDD0E8',
  sage: '#85A37F',
  terracotta: '#BD614D',
  softTerracotta: '#EAB9A8',
  shadow: '#6B4A3D',
  white: '#FFFFFF',
};

export default function App() {
  const [projects, setProjects] = useState<StitchProject[]>([]);
  const [selectedProjectID, setSelectedProjectID] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    let isMounted = true;

    async function loadProjects() {
      try {
        const storedProjects = await AsyncStorage.getItem(STORAGE_KEY);
        if (!isMounted) {
          return;
        }

        if (storedProjects) {
          const decodedProjects = JSON.parse(storedProjects);
          setProjects(normalizeProjects(decodedProjects));
        }
      } catch (error) {
        console.warn('No se pudieron cargar los proyectos', error);
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    }

    loadProjects();

    return () => {
      isMounted = false;
    };
  }, []);

  useEffect(() => {
    if (isLoading) {
      return;
    }

    AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(projects)).catch((error) => {
      console.warn('No se pudieron guardar los proyectos', error);
    });
  }, [isLoading, projects]);

  const selectedProject = useMemo(
    () => projects.find((project) => project.id === selectedProjectID) ?? null,
    [projects, selectedProjectID],
  );

  function addProject() {
    const project: StitchProject = {
      id: createProjectID(),
      name: 'Nuevo proyecto',
      rowCount: 0,
      stitchCount: 0,
      rowCounterName: DEFAULT_ROW_COUNTER_NAME,
      stitchCounterName: DEFAULT_STITCH_COUNTER_NAME,
    };

    setProjects((currentProjects) => [project, ...currentProjects]);
    setSelectedProjectID(project.id);
  }

  function deleteProject(project: StitchProject) {
    Alert.alert(
      'Borrar proyecto',
      `¿Querés borrar "${displayProjectName(project)}" y su contador?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Borrar',
          style: 'destructive',
          onPress: () => {
            setProjects((currentProjects) =>
              currentProjects.filter((currentProject) => currentProject.id !== project.id),
            );

            if (selectedProjectID === project.id) {
              setSelectedProjectID(null);
            }
          },
        },
      ],
    );
  }

  function updateProject(
    projectID: string,
    updater: (project: StitchProject) => StitchProject,
  ) {
    setProjects((currentProjects) =>
      currentProjects.map((project) => (project.id === projectID ? updater(project) : project)),
    );
  }

  function updateProjectName(projectID: string, name: string) {
    updateProject(projectID, (project) => ({
      ...project,
      name,
    }));
  }

  function updateCounterName(projectID: string, kind: CounterKind, name: string) {
    updateProject(projectID, (project) => ({
      ...project,
      rowCounterName: kind === 'rows' ? name : project.rowCounterName,
      stitchCounterName: kind === 'stitches' ? name : project.stitchCounterName,
    }));
  }

  function adjustCounter(projectID: string, kind: CounterKind, amount: number) {
    updateProject(projectID, (project) => ({
      ...project,
      rowCount:
        kind === 'rows'
          ? Math.max(0, project.rowCount + amount)
          : project.rowCount,
      stitchCount:
        kind === 'stitches'
          ? Math.max(0, project.stitchCount + amount)
          : project.stitchCount,
    }));
  }

  function confirmReset(project: StitchProject, kind: CounterKind) {
    const counterName =
      kind === 'rows'
        ? displayCounterName(project.rowCounterName, DEFAULT_ROW_COUNTER_NAME)
        : displayCounterName(project.stitchCounterName, DEFAULT_STITCH_COUNTER_NAME);

    Alert.alert(
      `Reiniciar ${counterName.toLowerCase()}`,
      `¿Querés volver ${counterName.toLowerCase()} a cero?`,
      [
        { text: 'Cancelar', style: 'cancel' },
        {
          text: 'Reiniciar',
          style: 'destructive',
          onPress: () => {
            updateProject(project.id, (currentProject) => ({
              ...currentProject,
              rowCount: kind === 'rows' ? 0 : currentProject.rowCount,
              stitchCount: kind === 'stitches' ? 0 : currentProject.stitchCount,
            }));
          },
        },
      ],
    );
  }

  if (isLoading) {
    return (
      <SafeAreaView style={styles.screen}>
        <StatusBar style="dark" />
        <View style={styles.loadingContainer}>
          <ActivityIndicator color={colors.terracotta} />
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar style="dark" />
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.keyboardContainer}
      >
        {selectedProject ? (
          <ProjectDetail
            project={selectedProject}
            onBack={() => setSelectedProjectID(null)}
            onChangeProjectName={(name) => updateProjectName(selectedProject.id, name)}
            onChangeCounterName={(kind, name) =>
              updateCounterName(selectedProject.id, kind, name)
            }
            onAddCounter={(kind) => adjustCounter(selectedProject.id, kind, 1)}
            onSubtractCounter={(kind) => adjustCounter(selectedProject.id, kind, -1)}
            onResetCounter={(kind) => confirmReset(selectedProject, kind)}
          />
        ) : (
          <ProjectList
            projects={projects}
            onAddProject={addProject}
            onOpenProject={setSelectedProjectID}
            onDeleteProject={deleteProject}
          />
        )}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

type ProjectListProps = {
  projects: StitchProject[];
  onAddProject: () => void;
  onOpenProject: (projectID: string) => void;
  onDeleteProject: (project: StitchProject) => void;
};

function ProjectList({
  projects,
  onAddProject,
  onOpenProject,
  onDeleteProject,
}: ProjectListProps) {
  return (
    <View style={styles.content}>
      <View style={styles.header}>
        <Text style={styles.appTitle}>StitchCounter</Text>
        <Text style={styles.subtitle}>Proyectos</Text>
      </View>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Agregar proyecto"
        onPress={onAddProject}
        style={({ pressed }) => [styles.addButton, pressed && styles.pressed]}
      >
        <Text style={styles.addButtonText}>+ Agregar proyecto</Text>
      </Pressable>

      {projects.length === 0 ? (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyTitle}>Todavía no hay proyectos</Text>
          <Text style={styles.emptyText}>Agregá uno para empezar a contar puntos y vueltas.</Text>
        </View>
      ) : (
        <ScrollView
          contentContainerStyle={styles.projectList}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {projects.map((project) => (
            <ProjectRow
              key={project.id}
              project={project}
              onOpen={() => onOpenProject(project.id)}
              onDelete={() => onDeleteProject(project)}
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
};

function ProjectRow({ project, onOpen, onDelete }: ProjectRowProps) {
  return (
    <View style={styles.projectRow}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Abrir ${displayProjectName(project)}`}
        onPress={onOpen}
        style={({ pressed }) => [styles.projectRowContent, pressed && styles.pressed]}
      >
        <View style={styles.projectTextGroup}>
          <Text style={styles.projectName} numberOfLines={2}>
            {displayProjectName(project)}
          </Text>
          <View style={styles.projectSummary}>
            <Text style={styles.projectSummaryText} numberOfLines={1}>
              {displayCounterName(project.rowCounterName, DEFAULT_ROW_COUNTER_NAME)}:{' '}
              {project.rowCount}
            </Text>
            <Text style={styles.projectSummaryText} numberOfLines={1}>
              {displayCounterName(project.stitchCounterName, DEFAULT_STITCH_COUNTER_NAME)}:{' '}
              {project.stitchCount}
            </Text>
          </View>
        </View>
        <Text style={styles.chevron}>›</Text>
      </Pressable>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Borrar ${displayProjectName(project)}`}
        onPress={onDelete}
        style={({ pressed }) => [styles.deleteButton, pressed && styles.pressed]}
      >
        <Text style={styles.deleteButtonText}>×</Text>
      </Pressable>
    </View>
  );
}

type ProjectDetailProps = {
  project: StitchProject;
  onBack: () => void;
  onChangeProjectName: (name: string) => void;
  onChangeCounterName: (kind: CounterKind, name: string) => void;
  onAddCounter: (kind: CounterKind) => void;
  onSubtractCounter: (kind: CounterKind) => void;
  onResetCounter: (kind: CounterKind) => void;
};

function ProjectDetail({
  project,
  onBack,
  onChangeProjectName,
  onChangeCounterName,
  onAddCounter,
  onSubtractCounter,
  onResetCounter,
}: ProjectDetailProps) {
  return (
    <ScrollView
      contentContainerStyle={styles.detailContent}
      keyboardShouldPersistTaps="handled"
      showsVerticalScrollIndicator={false}
    >
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Volver a proyectos"
        onPress={onBack}
        style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}
      >
        <Text style={styles.backButtonText}>‹ Proyectos</Text>
      </Pressable>

      <View style={styles.header}>
        <TextInput
          accessibilityLabel="Nombre del proyecto"
          onChangeText={onChangeProjectName}
          placeholder="Nombre del proyecto"
          placeholderTextColor={colors.secondaryText}
          returnKeyType="done"
          style={styles.projectTitleInput}
          value={project.name}
        />
        <Text style={styles.subtitle}>Contador de puntos y vueltas</Text>
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

      <Text accessibilityLabel={`${displayTitle}: ${value}`} style={styles.counterValue}>
        {value}
      </Text>

      <View style={styles.counterButtons}>
        <RoundCounterButton
          accessibilityLabel={`Restar ${displayTitle.toLowerCase()}`}
          backgroundColor={colors.lavender}
          foregroundColor={colors.text}
          onPress={onMinus}
          symbol="-"
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
        accessibilityRole="button"
        accessibilityLabel={`Reiniciar ${displayTitle.toLowerCase()}`}
        onPress={onReset}
        style={({ pressed }) => [styles.resetButton, pressed && styles.pressed]}
      >
        <Text style={styles.resetButtonText}>Reiniciar {displayTitle.toLowerCase()}</Text>
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
};

function RoundCounterButton({
  symbol,
  backgroundColor,
  foregroundColor,
  accessibilityLabel,
  onPress,
}: RoundCounterButtonProps) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={accessibilityLabel}
      onPress={onPress}
      style={({ pressed }) => [
        styles.roundButton,
        { backgroundColor },
        pressed && styles.roundButtonPressed,
      ]}
    >
      <Text style={[styles.roundButtonText, { color: foregroundColor }]}>{symbol}</Text>
    </Pressable>
  );
}

function createProjectID() {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}

function displayProjectName(project: StitchProject) {
  const trimmedName = project.name.trim();
  return trimmedName.length > 0 ? trimmedName : 'Proyecto sin nombre';
}

function displayCounterName(name: string, defaultName: string) {
  const trimmedName = name.trim();
  return trimmedName.length > 0 ? trimmedName : defaultName;
}

function normalizeProjects(value: unknown): StitchProject[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.map((project) => {
    const storedProject = project as Partial<StitchProject>;

    return {
      id: typeof storedProject.id === 'string' ? storedProject.id : createProjectID(),
      name: typeof storedProject.name === 'string' ? storedProject.name : 'Nuevo proyecto',
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
    };
  });
}

function normalizeCount(value: unknown) {
  return typeof value === 'number' && Number.isFinite(value) ? Math.max(0, value) : 0;
}

const styles = StyleSheet.create({
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
    paddingHorizontal: 22,
    paddingTop: 18,
  },
  detailContent: {
    flexGrow: 1,
    paddingBottom: 28,
    paddingHorizontal: 22,
    paddingTop: 12,
  },
  header: {
    alignItems: 'center',
    marginBottom: 18,
  },
  appTitle: {
    color: colors.text,
    fontSize: 34,
    fontWeight: '800',
    letterSpacing: 0,
    marginBottom: 6,
  },
  subtitle: {
    color: colors.secondaryText,
    fontSize: 17,
    fontWeight: '600',
    letterSpacing: 0,
  },
  addButton: {
    alignItems: 'center',
    backgroundColor: colors.dustyRose,
    borderRadius: 18,
    marginBottom: 18,
    paddingVertical: 14,
  },
  addButtonText: {
    color: colors.white,
    fontSize: 17,
    fontWeight: '700',
    letterSpacing: 0,
  },
  projectList: {
    paddingBottom: 22,
    rowGap: 14,
  },
  emptyCard: {
    alignItems: 'center',
    backgroundColor: colors.card,
    borderRadius: 24,
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
    fontSize: 22,
    fontWeight: '700',
    letterSpacing: 0,
    marginBottom: 10,
    textAlign: 'center',
  },
  emptyText: {
    color: colors.secondaryText,
    fontSize: 16,
    fontWeight: '600',
    letterSpacing: 0,
    textAlign: 'center',
  },
  projectRow: {
    alignItems: 'center',
    backgroundColor: colors.card,
    borderRadius: 24,
    flexDirection: 'row',
    gap: 10,
    paddingHorizontal: 18,
    paddingVertical: 18,
    shadowColor: colors.shadow,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.12,
    shadowRadius: 12,
    elevation: 3,
  },
  projectRowContent: {
    alignItems: 'center',
    flex: 1,
    flexDirection: 'row',
    gap: 12,
    minHeight: 54,
  },
  projectTextGroup: {
    flex: 1,
  },
  projectName: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '700',
    letterSpacing: 0,
    marginBottom: 8,
  },
  projectSummary: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 14,
  },
  projectSummaryText: {
    color: colors.secondaryText,
    fontSize: 14,
    fontWeight: '600',
    letterSpacing: 0,
  },
  chevron: {
    color: colors.secondaryText,
    fontSize: 28,
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
  backButton: {
    alignSelf: 'flex-start',
    marginBottom: 10,
    paddingVertical: 8,
  },
  backButtonText: {
    color: colors.terracotta,
    fontSize: 17,
    fontWeight: '700',
    letterSpacing: 0,
  },
  projectTitleInput: {
    color: colors.text,
    fontSize: 34,
    fontWeight: '800',
    letterSpacing: 0,
    marginBottom: 6,
    minHeight: 44,
    paddingHorizontal: 4,
    textAlign: 'center',
    width: '100%',
  },
  counterStack: {
    gap: 18,
  },
  counterCard: {
    alignItems: 'center',
    backgroundColor: colors.card,
    borderRadius: 28,
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
  pressed: {
    opacity: 0.72,
  },
});
