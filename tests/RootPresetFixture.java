// Diagnostic bridge: use the actual Kotlin planner, not a duplicated SQL template.
import java.util.*;
import java.lang.reflect.*;
import java.nio.charset.StandardCharsets;

public final class RootPresetFixture {
    public static void main(String[] args) throws Exception {
        Class<?> plan = Class.forName("com.topjohnwu.magisk.core.tasks.LDMaskRootPresetPlan");
        Object instance = plan.getField("INSTANCE").get(null);
        Class<?> pair = Class.forName("kotlin.Pair");
        Constructor<?> ctor = pair.getConstructor(Object.class, Object.class);
        List<Object> targets = new ArrayList<>();
        targets.add(ctor.newInstance("com.vng.playtogether", "com.vng.playtogether"));
        targets.add(ctor.newInstance("com.vng.playtogether", "com.vng.playtogether:adnw"));
        targets.add(ctor.newInstance("com.haegin.playtogether", "com.haegin.playtogether"));
        for (String method : new String[]{"sql", "verifySql", "script"}) {
            String value = (String)plan.getMethod(method, Collection.class).invoke(instance, targets);
            System.out.println(method + "=" + Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8)));
        }
    }
}
